import { getRecoverAccountSignature } from "@/test/helpers/sign-utils";
import EntryPointArtifact from "@account-abstraction/contracts/artifacts/EntryPoint.json";
import {
  Account,
  AccountSubscriptionManager,
  ERC20Mock,
  IEntryPoint,
  RecoveryManagerMock,
  SignatureRecoveryStrategy,
} from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("Account", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;

  const paymentTokenSubscriptionCost = wei(5);

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;

  let recoveryManager: RecoveryManagerMock;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  let entryPoint: IEntryPoint;
  let account: Account;

  before(async () => {
    [OWNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");
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
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");
    recoveryManager = await ethers.deployContract("RecoveryManagerMock");

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    const EntryPointFactory = await ethers.getContractFactoryFromArtifact(EntryPointArtifact);
    entryPoint = (await EntryPointFactory.deploy()) as any;

    account = await ethers.deployContract("Account");

    await account.initialize(MASTER_KEY1);

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await reverter.snapshot();
  });

  beforeEach(async () => {
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

    await paymentToken.connect(FIRST).transfer(account, paymentTokenSubscriptionCost);

    const approveData = paymentToken.interface.encodeFunctionData("approve", [
      await recoveryManager.getAddress(),
      paymentTokenSubscriptionCost,
    ]);

    await account.connect(MASTER_KEY1).execute(paymentToken, 0, approveData);

    await account.connect(MASTER_KEY1).addRecoveryProvider(recoveryManager, subscribeData);
  });

  afterEach(reverter.revert);

  describe("#recoverOwnership", () => {
    it("should recover ownership correctly", async () => {
      expect(await account.trustedExecutor()).to.be.eq(MASTER_KEY1);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        newOwner: SECOND.address,
        nonce: 0n,
      });

      let tx = await account.connect(OWNER).recoverOwnership(SECOND, recoveryManager, signature);

      await expect(tx).to.emit(account, "OwnershipRecovered").withArgs(MASTER_KEY1.address, SECOND.address);

      expect(await account.trustedExecutor()).to.be.eq(SECOND);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: await account.getAddress(),
        newOwner: SECOND.address,
        nonce: 0n,
      });

      await expect(
        account.connect(FIRST).recoverOwnership(SECOND, recoveryManager, signature),
      ).to.be.revertedWithCustomError(recoveryStrategy, "RecoveryFailed");

      await paymentToken.connect(FIRST).transfer(account, wei(10));

      const transferData = paymentToken.interface.encodeFunctionData("transfer", [OWNER.address, wei(10)]);

      await expect(account.connect(MASTER_KEY1).execute(paymentToken, 0, transferData))
        .to.be.revertedWithCustomError(account, "InvalidExecutor")
        .withArgs(MASTER_KEY1.address);

      tx = await account.connect(SECOND).execute(paymentToken, 0, transferData);

      await expect(tx).to.changeTokenBalances(paymentToken, [account, OWNER], [-wei(10), wei(10)]);
    });
  });
});
