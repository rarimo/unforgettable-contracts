import { getRecoverAccountSignature } from "@/test/helpers/sign-utils";
import {
  AccountMock,
  AccountSubscriptionManager,
  ERC20Mock,
  RecoveryManager,
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

  const mode = "0x0100000000000000000000000000000000000000000000000000000000000000";

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;

  let recoveryManager: RecoveryManager;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  let account: AccountMock;

  before(async () => {
    [OWNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    const recoveryManagerImpl = await ethers.deployContract("RecoveryManager");
    const recoveryManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await recoveryManagerImpl.getAddress(),
      "0x",
    ]);

    recoveryManager = await ethers.getContractAt("RecoveryManager", await recoveryManagerProxy.getAddress());

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(address,uint64,address,(address,uint256)[],(address,uint64)[])",
      [
        await recoveryManager.getAddress(),
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

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    account = await ethers.deployContract("AccountMock", [MASTER_KEY1.address]);

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await reverter.snapshot();
  });

  beforeEach(async () => {
    await paymentToken.connect(FIRST).transfer(account, paymentTokenSubscriptionCost);

    const approveData = paymentToken.interface.encodeFunctionData("approve", [
      await recoveryManager.getAddress(),
      paymentTokenSubscriptionCost,
    ]);

    const executionData = ethers.AbiCoder.defaultAbiCoder().encode(
      ["tuple(address,uint256,bytes)[]"],
      [[[await paymentToken.getAddress(), 0, approveData]]],
    );

    await account.connect(MASTER_KEY1).execute(mode, executionData);

    const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

    const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
      ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
      [
        [
          await subscriptionManager.getAddress(),
          await paymentToken.getAddress(),
          basePeriodDuration,
          [[0n, accountRecoveryData]],
        ],
      ],
    );

    await account.connect(MASTER_KEY1).addRecoveryProvider(recoveryManager, subscribeData);
  });

  afterEach(reverter.revert);

  describe("#addRecoveryProvider", () => {
    it("should add recovery provider correctly", async () => {
      expect(await account.getRecoveryProviders()).to.deep.eq([await recoveryManager.getAddress()]);
    });

    it("should not allow to add recovery provider if the caller is not self or trusted executor", async () => {
      await expect(account.connect(SECOND).addRecoveryProvider(recoveryManager, "0x"))
        .to.be.revertedWithCustomError(account, "NotSelfOrTrustedExecutor")
        .withArgs(SECOND.address);
    });
  });

  describe("#removeRecoveryProvider", () => {
    it("should remove recovery provider correctly", async () => {
      const tx = await account.connect(MASTER_KEY1).removeRecoveryProvider(recoveryManager);

      await expect(tx)
        .to.emit(account, "RecoveryProviderRemoved")
        .withArgs(await recoveryManager.getAddress());

      expect(await account.getRecoveryProviders()).to.deep.eq([]);
    });

    it("should not allow to remove recovery provider if the caller is not self or trusted executor", async () => {
      await expect(account.connect(FIRST).removeRecoveryProvider(recoveryManager))
        .to.be.revertedWithCustomError(account, "NotSelfOrTrustedExecutor")
        .withArgs(FIRST.address);
    });
  });

  describe("#recoverOwnership", () => {
    it("should recover ownership correctly", async () => {
      expect(await account.getTrustedExecutor()).to.be.eq(MASTER_KEY1);

      const subject = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        objectHash: ethers.keccak256(subject),
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      let tx = await account.connect(OWNER).recoverAccess(subject, recoveryManager, recoveryProof);

      await expect(tx).to.emit(account, "AccessRecovered").withArgs(subject);

      expect(await account.getTrustedExecutor()).to.be.eq(SECOND);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: await account.getAddress(),
        objectHash: ethers.keccak256(subject),
        nonce: 0n,
      });

      recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      await expect(
        account.connect(FIRST).recoverAccess(subject, recoveryManager, recoveryProof),
      ).to.be.revertedWithCustomError(recoveryStrategy, "InvalidSignature");

      await paymentToken.connect(FIRST).transfer(account, wei(10));

      const transferData = paymentToken.interface.encodeFunctionData("transfer", [OWNER.address, wei(10)]);

      const executionData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,uint256,bytes)[]"],
        [[[await paymentToken.getAddress(), 0, transferData]]],
      );

      await expect(account.connect(MASTER_KEY1).execute(mode, executionData))
        .to.be.revertedWithCustomError(account, "NotSelfOrTrustedExecutor")
        .withArgs(MASTER_KEY1.address);

      tx = await account.connect(SECOND).execute(mode, executionData);

      await expect(tx).to.changeTokenBalances(paymentToken, [account, OWNER], [-wei(10), wei(10)]);
    });
  });
});
