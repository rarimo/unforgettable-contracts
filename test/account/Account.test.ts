import { getRecoverAccountSignature } from "@/test/helpers/sign-utils";
import {
  AccountMock,
  AccountSubscriptionManager,
  ERC20Mock,
  RecoveryManager,
  SignatureRecoveryStrategy,
  SubscriptionsSynchronizer,
} from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("Account", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;

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

  let subscriptionsSynchronizer: SubscriptionsSynchronizer;

  let paymentToken: ERC20Mock;

  let account: AccountMock;

  function encodeAddress(address: string): string {
    return ethers.AbiCoder.defaultAbiCoder().encode(["address"], [address]);
  }

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
    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);

    subscriptionManager = await ethers.getContractAt(
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

    const subscriptionsSynchronizerImpl = await ethers.deployContract("SubscriptionsSynchronizer");
    const subscriptionsSynchronizerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionsSynchronizerImpl.getAddress(),
      "0x",
    ]);

    subscriptionsSynchronizer = await ethers.getContractAt(
      "SubscriptionsSynchronizer",
      await subscriptionsSynchronizerProxy.getAddress(),
    );

    await subscriptionsSynchronizer.initialize({
      wormholeRelayer: SECOND.address,
      crossChainTxGasLimit: 500000n,
      SMTMaxDepth: 80,
      subscriptionManagers: [await subscriptionManager.getAddress()],
      destinations: [],
    });

    recoveryManager = await ethers.getContractAt("RecoveryManager", await recoveryManagerProxy.getAddress());

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    await subscriptionManager.initialize({
      subscriptionCreators: [await recoveryManager.getAddress()],
      tokensPaymentInitData: {
        basePaymentPeriod: basePaymentPeriod,
        durationFactorEntries: [],
        paymentTokenEntries: [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
      },
      sbtPaymentInitData: {
        sbtEntries: [],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: OWNER,
      },
      crossChainInitData: {
        subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
      },
    });

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
          basePaymentPeriod,
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

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        object: encodeAddress(SECOND.address),
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      const subject = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      let tx = await account.connect(OWNER).recoverAccess(subject, recoveryManager, recoveryProof);

      await expect(tx).to.emit(account, "AccessRecovered").withArgs(subject);

      expect(await account.getTrustedExecutor()).to.be.eq(SECOND);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: await account.getAddress(),
        object: encodeAddress(SECOND.address),
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
