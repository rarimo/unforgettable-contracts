import { ERC20Mock, Vault, VaultFactory, VaultSubscriptionManager } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

import {
  getUpdateEnabledStatusSignature,
  getUpdateMasterKeySignature,
  getWithdrawTokensSignature,
} from "../helpers/sign-utils";

describe("Vault", () => {
  const reverter = new Reverter();

  const basePaymentPeriod = 3600n * 24n * 30n;
  const nativeSubscriptionCost = wei(1, 15);
  const initialSubscriptionDuration = basePaymentPeriod * 12n;

  let OWNER: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;
  let MASTER_KEY2: SignerWithAddress;

  let vault: Vault;
  let vaultFactory: VaultFactory;
  let subscriptionManager: VaultSubscriptionManager;

  let testERC20: ERC20Mock;

  before(async () => {
    [OWNER, SUBSCRIPTION_SIGNER, FIRST, MASTER_KEY1, MASTER_KEY2] = await ethers.getSigners();

    testERC20 = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    const vaultImpl = await ethers.deployContract("Vault");
    const vaultFactoryImpl = await ethers.deployContract("VaultFactory");

    const vaultFactoryProxy = await ethers.deployContract("ERC1967Proxy", [await vaultFactoryImpl.getAddress(), "0x"]);

    const subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManager");
    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);

    vaultFactory = await ethers.getContractAt("VaultFactory", await vaultFactoryProxy.getAddress());
    subscriptionManager = await ethers.getContractAt(
      "VaultSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    await vaultFactory.initialize(vaultImpl, subscriptionManager);
    await subscriptionManager.initialize({
      subscriptionCreators: [],
      vaultFactoryAddr: await vaultFactory.getAddress(),
      vaultNameRetentionPeriod: 3600n * 24n,
      vaultPaymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseVaultNameCost: nativeSubscriptionCost,
        },
      ],
      tokensPaymentInitData: {
        basePaymentPeriod: basePaymentPeriod,
        durationFactorEntries: [],
        paymentTokenEntries: [
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
          },
        ],
      },
      sbtPaymentInitData: {
        sbtEntries: [],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: SUBSCRIPTION_SIGNER,
      },
    });

    const masterKeyNonce = await vaultFactory.nonces(MASTER_KEY1);
    const expectedVaultAddr = await vaultFactory.predictVaultAddress(vaultImpl, MASTER_KEY1, masterKeyNonce);

    const expectedSubscriptionCost = await subscriptionManager.getSubscriptionCost(
      expectedVaultAddr,
      ETHER_ADDR,
      initialSubscriptionDuration,
    );

    await vaultFactory.connect(FIRST).deployVault(MASTER_KEY1, ETHER_ADDR, initialSubscriptionDuration, "abcd", {
      value: expectedSubscriptionCost * 2n,
    });

    vault = await ethers.getContractAt("Vault", expectedVaultAddr);

    expect(await vault.isVaultEnabled()).to.be.true;

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await vault.owner()).to.be.eq(MASTER_KEY1);
      expect(await vault.getVaultFactory()).to.be.eq(vaultFactory);
    });

    it("should get exception if try to call init function twice", async () => {
      await expect(vault.initialize(OWNER)).to.be.revertedWithCustomError(vault, "InvalidInitialization");
    });
  });

  describe("#receive", () => {
    const amountToDeposit = wei(5, 17);

    it("should correctly deposit native tokens through receive function", async () => {
      const tx = await OWNER.sendTransaction({
        to: vault,
        value: amountToDeposit,
      });

      await expect(tx).to.emit(vault, "TokensDeposited").withArgs(ETHER_ADDR, OWNER.address, amountToDeposit);
      expect(await vault.getBalance(ETHER_ADDR)).to.be.eq(amountToDeposit);
    });

    it("should get exception if limit exceeded", async () => {
      const newLimit = wei(7, 17);

      await vaultFactory.updateTokenLimitAmount(ETHER_ADDR, newLimit);

      await OWNER.sendTransaction({
        to: vault,
        value: amountToDeposit,
      });

      expect(await vault.getBalance(ETHER_ADDR)).to.be.eq(amountToDeposit);

      await expect(
        OWNER.sendTransaction({
          to: vault,
          value: amountToDeposit,
        }),
      )
        .to.be.revertedWithCustomError(vault, "TokenLimitExceeded")
        .withArgs(ETHER_ADDR);
    });

    it("should get exception if vault is not enabled", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateEnabledStatusSignature(vault, MASTER_KEY1, {
        enabled: false,
        nonce: currentNonce,
      });

      await vault.updateEnabledStatus(false, signature);

      expect(await vault.isVaultEnabled()).to.be.false;

      await expect(
        OWNER.sendTransaction({
          to: vault,
          value: amountToDeposit,
        }),
      ).to.be.revertedWithCustomError(vault, "VaultIsNotEnabled");
    });
  });

  describe("#updateMasterKey", () => {
    it("should correctly update master key", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateMasterKeySignature(vault, MASTER_KEY1, {
        newMasterKey: MASTER_KEY2.address,
        nonce: currentNonce,
      });

      const tx = await vault.updateMasterKey(MASTER_KEY2, signature);

      await expect(tx).to.emit(vault, "OwnershipTransferred").withArgs(MASTER_KEY1.address, MASTER_KEY2.address);
      expect(await vault.owner()).to.be.eq(MASTER_KEY2.address);
      expect(await vault.nonces(MASTER_KEY1)).to.be.eq(currentNonce + 1n);
    });

    it("should get exception if pass zero master key", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateMasterKeySignature(vault, MASTER_KEY1, {
        newMasterKey: ethers.ZeroAddress,
        nonce: currentNonce,
      });

      await expect(vault.updateMasterKey(ethers.ZeroAddress, signature)).to.be.revertedWithCustomError(
        vault,
        "ZeroMasterKey",
      );
    });

    it("should get exception if pass invalid signature", async () => {
      const signature = await getUpdateMasterKeySignature(vault, FIRST, {
        newMasterKey: FIRST.address,
        nonce: 999n,
      });

      await expect(vault.connect(FIRST).updateMasterKey(FIRST.address, signature)).to.be.revertedWithCustomError(
        vault,
        "InvalidSignature",
      );
    });
  });

  describe("#updateEnabledStatus", () => {
    it("should correctly update enabled status", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateEnabledStatusSignature(vault, MASTER_KEY1, {
        enabled: false,
        nonce: currentNonce,
      });

      const tx = await vault.updateEnabledStatus(false, signature);

      await expect(tx).to.emit(vault, "EnabledStatusUpdated").withArgs(false);
      expect(await vault.isVaultEnabled()).to.be.false;
    });

    it("should get exception if pass current enabled status", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateEnabledStatusSignature(vault, MASTER_KEY1, {
        enabled: true,
        nonce: currentNonce,
      });

      await expect(vault.updateEnabledStatus(true, signature)).to.be.revertedWithCustomError(
        vault,
        "InvalidNewEnabledStatus",
      );
    });

    it("should get exception if pass invalid signature", async () => {
      const currentNonce = await vault.nonces(FIRST);
      const signature = await getUpdateEnabledStatusSignature(vault, FIRST, {
        enabled: true,
        nonce: currentNonce,
      });

      await expect(vault.connect(FIRST).updateEnabledStatus(true, signature)).to.be.revertedWithCustomError(
        vault,
        "InvalidSignature",
      );
    });
  });

  describe("#withdrawTokens", () => {
    it("should correctly withdraw native currency", async () => {
      const amountToDeposit = wei(1);

      await OWNER.sendTransaction({
        to: vault,
        value: amountToDeposit,
      });

      const amountToWithdraw = wei(3, 17);
      const currentNonce = await vault.nonces(MASTER_KEY1);

      const signature = await getWithdrawTokensSignature(vault, MASTER_KEY1, {
        token: ETHER_ADDR,
        to: FIRST.address,
        amount: amountToWithdraw,
        nonce: currentNonce,
      });

      const tx = await vault.withdrawTokens(ETHER_ADDR, FIRST.address, amountToWithdraw, signature);

      await expect(tx).to.emit(vault, "TokensWithdrawn").withArgs(ETHER_ADDR, FIRST.address, amountToWithdraw);
      await expect(tx).to.changeEtherBalances([vault, FIRST], [-amountToWithdraw, amountToWithdraw]);
    });

    it("should correctly withdraw ERC20 tokens", async () => {
      const amountToDeposit = wei(100);
      await testERC20.mint(vault, amountToDeposit);

      const amountToWithdraw = wei(55);
      const currentNonce = await vault.nonces(MASTER_KEY1);

      const signature = await getWithdrawTokensSignature(vault, MASTER_KEY1, {
        token: await testERC20.getAddress(),
        to: FIRST.address,
        amount: amountToWithdraw,
        nonce: currentNonce,
      });

      const tx = await vault.withdrawTokens(await testERC20.getAddress(), FIRST.address, amountToWithdraw, signature);

      await expect(tx)
        .to.emit(vault, "TokensWithdrawn")
        .withArgs(await testERC20.getAddress(), FIRST.address, amountToWithdraw);
      await expect(tx).to.changeTokenBalances(testERC20, [vault, FIRST], [-amountToWithdraw, amountToWithdraw]);
    });

    it("should get exception if pass zero tokens amount", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);

      const signature = await getWithdrawTokensSignature(vault, MASTER_KEY1, {
        token: await testERC20.getAddress(),
        to: FIRST.address,
        amount: 0n,
        nonce: currentNonce,
      });

      await expect(
        vault.withdrawTokens(await testERC20.getAddress(), FIRST.address, 0n, signature),
      ).to.be.revertedWithCustomError(vault, "ZeroAmount");
    });

    it("should get exception if pass invalid signature", async () => {
      const amountToDeposit = wei(100);
      await testERC20.mint(vault, amountToDeposit);

      const amountToWithdraw = wei(55);
      const currentNonce = await vault.nonces(FIRST);
      const signature = await getWithdrawTokensSignature(vault, FIRST, {
        token: await testERC20.getAddress(),
        to: FIRST.address,
        amount: amountToWithdraw,
        nonce: currentNonce,
      });

      await expect(
        vault.connect(FIRST).withdrawTokens(await testERC20.getAddress(), FIRST.address, amountToWithdraw, signature),
      ).to.be.revertedWithCustomError(vault, "InvalidSignature");
    });

    it("should get exception if there is no active subscription", async () => {
      const amountToDeposit = wei(100);
      await testERC20.mint(vault, amountToDeposit);

      const amountToWithdraw = wei(55);
      const currentNonce = await vault.nonces(MASTER_KEY1);

      const signature = await getWithdrawTokensSignature(vault, MASTER_KEY1, {
        token: await testERC20.getAddress(),
        to: FIRST.address,
        amount: amountToWithdraw,
        nonce: currentNonce,
      });

      const subscriptionEndTime = await subscriptionManager.getSubscriptionEndTime(await vault.getAddress());

      await time.increaseTo(subscriptionEndTime + 100n);

      expect(await subscriptionManager.hasActiveSubscription(await vault.getAddress())).to.be.false;

      await expect(
        vault.withdrawTokens(await testERC20.getAddress(), FIRST.address, amountToWithdraw, signature),
      ).to.be.revertedWithCustomError(vault, "NoActiveSubscription");
    });
  });

  describe("#deposit", () => {
    it("should correctly deposit native currency without limits", async () => {
      const amountToDeposit = wei(1);

      let tx = await vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit * 2n });

      await expect(tx).to.emit(vault, "TokensDeposited").withArgs(ETHER_ADDR, OWNER.address, amountToDeposit);
      expect(await vault.getBalance(ETHER_ADDR)).to.be.eq(amountToDeposit);

      tx = await vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit });

      await expect(tx).to.emit(vault, "TokensDeposited").withArgs(ETHER_ADDR, OWNER.address, amountToDeposit);
      expect(await vault.getBalance(ETHER_ADDR)).to.be.eq(amountToDeposit * 2n);
    });

    it("should correctly deposit native currency with limits", async () => {
      const newLimit = wei(2);
      await vaultFactory.updateTokenLimitAmount(ETHER_ADDR, newLimit);

      const amountToDeposit = wei(1);

      const tx = await vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit * 2n });

      await expect(tx).to.emit(vault, "TokensDeposited").withArgs(ETHER_ADDR, OWNER.address, amountToDeposit);
      expect(await vault.getBalance(ETHER_ADDR)).to.be.eq(amountToDeposit);
    });

    it("should correctly deposit ERC20 tokens", async () => {
      const amountToDeposit = wei(1000);

      await testERC20.mint(OWNER, amountToDeposit);
      await testERC20.approve(await vault.getAddress(), amountToDeposit);

      const tx = await vault.deposit(await testERC20.getAddress(), amountToDeposit);

      await expect(tx)
        .to.emit(vault, "TokensDeposited")
        .withArgs(await testERC20.getAddress(), OWNER.address, amountToDeposit);
      expect(await testERC20.balanceOf(vault)).to.be.eq(amountToDeposit);
    });

    it("should get exception if the vault is not enabled", async () => {
      const currentNonce = await vault.nonces(MASTER_KEY1);
      const signature = await getUpdateEnabledStatusSignature(vault, MASTER_KEY1, {
        enabled: false,
        nonce: currentNonce,
      });

      await vault.updateEnabledStatus(false, signature);

      expect(await vault.isVaultEnabled()).to.be.false;

      const amountToDeposit = wei(1);

      await expect(
        vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit * 2n }),
      ).to.be.revertedWithCustomError(vault, "VaultIsNotEnabled");
    });

    it("should get exception if pass zero tokens amount", async () => {
      await expect(vault.deposit(ETHER_ADDR, 0n, { value: wei(1) })).to.be.revertedWithCustomError(vault, "ZeroAmount");
    });

    it("should get exception if token limit exceeded", async () => {
      const newLimit = wei(2);
      await vaultFactory.updateTokenLimitAmount(ETHER_ADDR, newLimit);

      const amountToDeposit = wei(16, 17);

      await vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit * 2n });

      await expect(vault.deposit(ETHER_ADDR, amountToDeposit, { value: amountToDeposit }))
        .to.be.revertedWithCustomError(vault, "TokenLimitExceeded")
        .withArgs(ETHER_ADDR);
    });
  });
});
