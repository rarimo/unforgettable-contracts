import { getRecoverAccountSignature, getRecoverOwnershipSignature } from "@/test/helpers/sign-utils";
import EntryPointArtifact from "@account-abstraction/contracts/artifacts/EntryPoint.json";
import {
  Account,
  AccountFactory,
  Account__factory,
  ERC20Mock,
  IEntryPoint,
  RecoveryManagerMock,
  SignatureRecoveryStrategy,
  SubscriptionManager,
} from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { AddressLike } from "ethers";
import { ethers } from "hardhat";

describe("Account", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;

  const paymentTokenSubscriptionCost = wei(5);

  const callGasLimit = 800_000n;
  const verificationGasLimit = 800_000n;
  const maxFeePerGas = ethers.parseUnits("10", "gwei");
  const maxPriorityFeePerGas = ethers.parseUnits("5", "gwei");

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let subscriptionManagerImpl: SubscriptionManager;
  let subscriptionManager: SubscriptionManager;

  let recoveryManager: RecoveryManagerMock;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  let entryPoint: IEntryPoint;

  let accountAddress: AddressLike;

  let Account: Account__factory;
  let account: Account;
  let accountFactory: AccountFactory;

  function packTwoUint128(a, b) {
    const maxUint128 = (1n << 128n) - 1n;

    if (a > maxUint128 || b > maxUint128) {
      throw new Error("Value exceeds uint128");
    }

    const packed = (a << 128n) + b;

    return "0x" + packed.toString(16).padStart(64, "0");
  }

  async function getUserOp(callData: string = "0x") {
    const accountGasLimits = packTwoUint128(callGasLimit, verificationGasLimit);
    const gasFees = packTwoUint128(maxFeePerGas, maxPriorityFeePerGas);

    const AccountFactory = await ethers.getContractFactory("AccountFactory");

    const initCode =
      (await ethers.provider.getCode(accountAddress)) === "0x"
        ? (await accountFactory.getAddress()) +
          AccountFactory.interface.encodeFunctionData("createAccount", [FIRST.address, 0]).slice(2)
        : "0x";

    return {
      sender: accountAddress.toString(),
      nonce: await entryPoint.getNonce(accountAddress, 0),
      initCode: initCode,
      callData: callData,
      accountGasLimits: accountGasLimits,
      preVerificationGas: 50_000n,
      gasFees: gasFees,
      paymasterAndData: "0x",
      signature: "0x",
    };
  }

  before(async () => {
    [OWNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    subscriptionManagerImpl = await ethers.deployContract("SubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(uint64,address,(address,uint256)[],(address,uint64)[])",
      [
        basePeriodDuration,
        OWNER.address,
        [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
        [],
      ],
    );

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      subscriptionManagerInitData,
    ]);
    subscriptionManager = await ethers.getContractAt(
      "SubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");
    recoveryManager = await ethers.deployContract("RecoveryManagerMock");

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    const EntryPointFactory = await ethers.getContractFactoryFromArtifact(EntryPointArtifact);
    entryPoint = (await EntryPointFactory.deploy()) as any;

    accountFactory = await ethers.deployContract("AccountFactory", [entryPoint]);

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await reverter.snapshot();
  });

  beforeEach(async () => {
    accountAddress = await accountFactory.getContractAddress(FIRST.address, 0);

    Account = await ethers.getContractFactory("Account");

    await entryPoint.depositTo(accountAddress, {
      value: ethers.parseEther("100"),
    });

    const userOp = await getUserOp();

    userOp.signature = await getRecoverOwnershipSignature(entryPoint, FIRST, userOp);

    await entryPoint.handleOps([userOp], FIRST.address);

    account = await ethers.getContractAt("Account", accountAddress);

    const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

    const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
      ["tuple(address,address,uint64,tuple(uint256,bytes))"],
      [
        [
          await subscriptionManager.getAddress(),
          await paymentToken.getAddress(),
          basePeriodDuration,
          [0n, accountRecoveryData],
        ],
      ],
    );

    const subscribeCost = await recoveryManager.getSubscribeCost(subscribeData);

    await paymentToken.connect(FIRST).approve(account, subscribeCost[0]);

    await account.connect(FIRST).addRecoveryProvider(recoveryManager, subscribeData);
  });

  afterEach(reverter.revert);

  describe("#recoverOwnership", () => {
    it("should recover ownership correctly", async () => {
      expect(await account.owner()).to.be.eq(FIRST);

      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        newOwner: SECOND.address,
        nonce: 0n,
      });

      const tx = await account.connect(OWNER).recoverOwnership(SECOND, recoveryManager, signature);

      await expect(tx).to.emit(account, "OwnershipRecovered").withArgs(FIRST.address, SECOND.address);

      expect(await account.owner()).to.be.eq(SECOND);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: await account.getAddress(),
        newOwner: SECOND.address,
        nonce: 0n,
      });

      await expect(
        account.connect(FIRST).recoverOwnership(SECOND, recoveryManager, signature),
      ).to.be.revertedWithCustomError(recoveryStrategy, "RecoveryFailed");
    });
  });
});
