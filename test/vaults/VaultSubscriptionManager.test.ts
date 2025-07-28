import { ERC20Mock, SBTMock, VaultFactoryMock, VaultSubscriptionManager } from "@ethers-v6";
import { ETHER_ADDR, PERCENTAGE_100, PRECISION, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { AddressLike } from "ethers";
import { ethers } from "hardhat";

import { getBuySubscriptionSignature, getUpdateVaultNameSignature } from "../helpers/sign-utils";

describe("VaultSubscriptionManager", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;
  const sbtSubscriptionTime = basePeriodDuration * 12n;

  const vaultNameRetentionPeriod = 3600n * 24n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  const nativeVaultNameCost = wei(1, 6);
  const paymentTokenVaultNameCost = wei(1);

  const threeLetterFactor = 50n;
  const fourLetterFactor = 5n;

  let OWNER: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let vaultFactory: VaultFactoryMock;
  let subscriptionManagerImpl: VaultSubscriptionManager;
  let subscriptionManager: VaultSubscriptionManager;

  let paymentToken: ERC20Mock;
  let sbtToken: SBTMock;

  before(async () => {
    [OWNER, SUBSCRIPTION_SIGNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);
    sbtToken = await ethers.deployContract("SBTMock");

    await sbtToken.initialize("Mock SBT", "MSBT", [OWNER]);

    vaultFactory = await ethers.deployContract("VaultFactoryMock");

    subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(uint64,uint64,address,(address,uint256, uint256)[],(address,uint64)[])",
      [
        basePeriodDuration,
        vaultNameRetentionPeriod,
        SUBSCRIPTION_SIGNER.address,
        [
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
            baseVaultNameCost: nativeVaultNameCost,
          },
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
            baseVaultNameCost: paymentTokenVaultNameCost,
          },
        ],
        [
          {
            sbtToken: await sbtToken.getAddress(),
            subscriptionTimePerToken: sbtSubscriptionTime,
          },
        ],
      ],
    );

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      subscriptionManagerInitData,
    ]);
    subscriptionManager = await ethers.getContractAt(
      "VaultSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    await subscriptionManager.secondStepInitialize(await vaultFactory.getAddress());

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await sbtToken.addOwners([subscriptionManager]);

    expect(await sbtToken.isOwner(subscriptionManager)).to.be.true;

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await subscriptionManager.owner()).to.be.eq(OWNER);
      expect(await subscriptionManager.implementation()).to.be.eq(subscriptionManagerImpl);
      expect(await subscriptionManager.getBasePeriodDuration()).to.be.eq(basePeriodDuration);
      expect(await subscriptionManager.getSubscriptionSigner()).to.be.eq(SUBSCRIPTION_SIGNER);
      expect(await subscriptionManager.getVaultNameRetentionPeriod()).to.be.eq(vaultNameRetentionPeriod);
      expect(await subscriptionManager.getVaultFactory()).to.be.eq(vaultFactory);

      expect(await subscriptionManager.getPaymentTokens()).to.be.deep.eq([ETHER_ADDR, await paymentToken.getAddress()]);
      expect(await subscriptionManager.getPaymentTokensSettings(ETHER_ADDR)).to.be.deep.eq([
        nativeSubscriptionCost,
        nativeVaultNameCost,
        true,
      ]);
      expect(await subscriptionManager.getPaymentTokensSettings(paymentToken)).to.be.deep.eq([
        paymentTokenSubscriptionCost,
        paymentTokenVaultNameCost,
        true,
      ]);
      expect(await subscriptionManager.isAvailableForPayment(ETHER_ADDR)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(nativeSubscriptionCost);
      expect(await subscriptionManager.isAvailableForPayment(paymentToken)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      expect(await subscriptionManager.isSupportedSBT(sbtToken)).to.be.true;
      expect(await subscriptionManager.getSubscriptionTimePerSBT(sbtToken)).to.be.eq(sbtSubscriptionTime);
    });

    it("should get exception if try to call init function twice", async () => {
      await expect(
        subscriptionManager.initialize(
          basePeriodDuration,
          vaultNameRetentionPeriod,
          SUBSCRIPTION_SIGNER.address,
          [],
          [],
        ),
      ).to.be.revertedWithCustomError(subscriptionManager, "InvalidInitialization");
    });

    it("should get exception if not an owner try to call secondStepInitialize function", async () => {
      await expect(subscriptionManager.connect(FIRST).secondStepInitialize(FIRST))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });

    it("should get exception if try to call secondStepInitialize function twice", async () => {
      await expect(subscriptionManager.secondStepInitialize(FIRST)).to.be.revertedWithCustomError(
        subscriptionManager,
        "InvalidInitialization",
      );
    });
  });

  describe("#upgrade", () => {
    it("should correctly upgrade VaultSubscriptionManager contract", async () => {
      const newSubscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManagerMock");

      const subscriptionManagerMock = await ethers.getContractAt("VaultSubscriptionManagerMock", subscriptionManager);

      await expect(subscriptionManagerMock.version()).to.be.revertedWithoutReason();

      await subscriptionManager.upgradeToAndCall(newSubscriptionManagerImpl, "0x");

      expect(await subscriptionManager.implementation()).to.be.eq(newSubscriptionManagerImpl);

      expect(await subscriptionManagerMock.version()).to.be.eq("v2.0.0");
    });

    it("should get exception if not an owner try to upgrade VaultFactory", async () => {
      const newSubscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManagerMock");

      await expect(subscriptionManager.connect(FIRST).upgradeToAndCall(newSubscriptionManagerImpl, "0x"))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#setSubscriptionSigner", () => {
    it("should correctly set new subscription signer", async () => {
      const tx = await subscriptionManager.setSubscriptionSigner(MASTER_KEY1);

      expect(await subscriptionManager.getSubscriptionSigner()).to.be.eq(MASTER_KEY1);

      await expect(tx).to.emit(subscriptionManager, "SubscriptionSignerUpdated").withArgs(MASTER_KEY1.address);
    });

    it("should get exception if pass zero address", async () => {
      await expect(subscriptionManager.setSubscriptionSigner(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        subscriptionManager,
        "ZeroAddr",
      );
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).setSubscriptionSigner(FIRST))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#setVaultNameRetentionPeriod", () => {
    it("should correctly set new vault name retention period", async () => {
      const tx = await subscriptionManager.setVaultNameRetentionPeriod(vaultNameRetentionPeriod / 2n);

      expect(await subscriptionManager.getVaultNameRetentionPeriod()).to.be.eq(vaultNameRetentionPeriod / 2n);

      await expect(tx)
        .to.emit(subscriptionManager, "VaultNameRetentionPeriodUpdated")
        .withArgs(vaultNameRetentionPeriod / 2n);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).setVaultNameRetentionPeriod(100n))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updatePaymentTokens", () => {
    it("should correctly add new payment tokens", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);
      const subscriptionCost = wei(5);
      const vaultNameCost = wei(2);

      const tx = await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await newToken.getAddress(),
          baseSubscriptionCost: subscriptionCost,
          baseVaultNameCost: vaultNameCost,
        },
      ]);

      expect(await subscriptionManager.isAvailableForPayment(await newToken.getAddress())).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(await newToken.getAddress())).to.be.eq(
        subscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseVaultNameCost(await newToken.getAddress())).to.be.eq(vaultNameCost);

      await expect(tx)
        .to.emit(subscriptionManager, "PaymentTokenUpdated")
        .withArgs(await newToken.getAddress(), subscriptionCost, vaultNameCost);
    });

    it("should correctly update subscription cost without status", async () => {
      await subscriptionManager.updateTokenPaymentStatus(ETHER_ADDR, false);

      expect(await subscriptionManager.isAvailableForPayment(ETHER_ADDR)).to.be.false;

      const newSubscriptionCost = nativeSubscriptionCost * 2n;
      const newVaultNameCost = nativeVaultNameCost * 2n;
      const tx = await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: newSubscriptionCost,
          baseVaultNameCost: newVaultNameCost,
        },
      ]);

      expect(await subscriptionManager.isAvailableForPayment(ETHER_ADDR)).to.be.false;

      await expect(tx)
        .to.emit(subscriptionManager, "PaymentTokenUpdated")
        .withArgs(ETHER_ADDR, newSubscriptionCost, newVaultNameCost);
    });

    it("should get exception if pass zero address", async () => {
      await expect(
        subscriptionManager.updatePaymentTokens([
          {
            paymentToken: ethers.ZeroAddress,
            baseSubscriptionCost: wei(1),
            baseVaultNameCost: wei(2),
          },
        ]),
      ).to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr");
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updatePaymentTokens([
          {
            paymentToken: FIRST.address,
            baseSubscriptionCost: wei(1),
            baseVaultNameCost: wei(2),
          },
        ]),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateSBTTokens", () => {
    it("should correctly update sbt tokens settings", async () => {
      const newSbtToken = await ethers.deployContract("SBTMock");
      const subscriptionTimePerToken = basePeriodDuration * 6n;

      const tx = await subscriptionManager.updateSBTTokens([
        {
          sbtToken: await newSbtToken.getAddress(),
          subscriptionTimePerToken: subscriptionTimePerToken,
        },
        {
          sbtToken: await sbtToken.getAddress(),
          subscriptionTimePerToken: 0n,
        },
      ]);

      await expect(tx)
        .to.emit(subscriptionManager, "SBTTokenUpdated")
        .withArgs(await newSbtToken.getAddress(), subscriptionTimePerToken);
      await expect(tx)
        .to.emit(subscriptionManager, "SBTTokenUpdated")
        .withArgs(await sbtToken.getAddress(), 0n);

      expect(await subscriptionManager.isSupportedSBT(newSbtToken)).to.be.true;
      expect(await subscriptionManager.isSupportedSBT(sbtToken)).to.be.false;
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updateSBTTokens([
          {
            sbtToken: FIRST.address,
            subscriptionTimePerToken: basePeriodDuration * 6n,
          },
        ]),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateTokenPaymentStatus", () => {
    it("should correctly update payment status", async () => {
      const tx = await subscriptionManager.updateTokenPaymentStatus(ETHER_ADDR, false);

      await expect(tx).to.emit(subscriptionManager, "TokenPaymentStatusUpdated").withArgs(ETHER_ADDR, false);

      expect(await subscriptionManager.isAvailableForPayment(ETHER_ADDR)).to.be.false;
    });

    it("should get exception if payment token is not configured", async () => {
      await expect(subscriptionManager.updateTokenPaymentStatus(FIRST.address, true))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotConfigured")
        .withArgs(FIRST.address);
    });

    it("should get exception if pass current status", async () => {
      await expect(subscriptionManager.updateTokenPaymentStatus(ETHER_ADDR, true))
        .to.be.revertedWithCustomError(subscriptionManager, "InvalidTokenPaymentStatus")
        .withArgs(ETHER_ADDR, true);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).updateTokenPaymentStatus(ETHER_ADDR, false))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateSubscriptionDurationFactor", () => {
    it("should correctly update subscription duration factor", async () => {
      const duration = basePeriodDuration * 12n;
      const factor = PRECISION * 95n;

      const tx = await subscriptionManager.updateSubscriptionDurationFactor(duration, factor);

      await expect(tx).to.emit(subscriptionManager, "SubscriptionDurationFactorUpdated").withArgs(duration, factor);

      expect(await subscriptionManager.getSubscriptionDurationFactor(duration)).to.be.eq(factor);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updateSubscriptionDurationFactor(basePeriodDuration * 6n, PRECISION * 90n),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#withdrawTokens", () => {
    it("should correctly withdraw native tokens", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      await subscriptionManager.buySubscription(FIRST, ETHER_ADDR, basePeriodDuration, {
        value: nativeSubscriptionCost,
      });

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;

      const tx = await subscriptionManager.withdrawTokens(ETHER_ADDR, FIRST, ethers.MaxUint256);

      await expect(tx)
        .to.emit(subscriptionManager, "TokensWithdrawn")
        .withArgs(ETHER_ADDR, FIRST, nativeSubscriptionCost);
      await expect(tx).to.changeEtherBalances(
        [subscriptionManager, FIRST],
        [-nativeSubscriptionCost, nativeSubscriptionCost],
      );
    });

    it("should correctly withdraw ERC20 tokens", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      const amountToWithdraw = wei(1000);

      await paymentToken.mint(subscriptionManager, amountToWithdraw);

      const tx = await subscriptionManager.withdrawTokens(paymentToken, FIRST, ethers.MaxUint256);

      await expect(tx)
        .to.emit(subscriptionManager, "TokensWithdrawn")
        .withArgs(await paymentToken.getAddress(), FIRST, amountToWithdraw);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [subscriptionManager, FIRST],
        [-amountToWithdraw, amountToWithdraw],
      );
    });

    it("should get exception if pass zero recipient address", async () => {
      await expect(
        subscriptionManager.withdrawTokens(ETHER_ADDR, ethers.ZeroAddress, wei(1)),
      ).to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr");
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).withdrawTokens(ETHER_ADDR, FIRST, wei(1)))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscription", () => {
    beforeEach("setup", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);
    });

    it("should correctly buy subscription for 2 base periods", async () => {
      const duration = basePeriodDuration * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), OWNER, expectedCost);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-expectedCost, expectedCost],
      );

      await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await paymentToken.getAddress(),
          baseSubscriptionCost: paymentTokenSubscriptionCost * 2n,
          baseVaultNameCost: paymentTokenVaultNameCost * 2n,
        },
      ]);

      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
      expect(await subscriptionManager.getBaseSubscriptionCostForAccount(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost * 2n,
      );
    });

    it("should correctly buy subscription for 2.5 base periods", async () => {
      const duration = (basePeriodDuration * 5n) / 2n;
      const expectedCost = (paymentTokenSubscriptionCost * 5n) / 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), OWNER, expectedCost);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-expectedCost, expectedCost],
      );

      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
    });

    it("should correctly buy and extend subscription", async () => {
      const duration = basePeriodDuration * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost * 2n);
      await paymentToken.approve(subscriptionManager, expectedCost * 2n);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration * 2n;

      await time.setNextBlockTimestamp(startTime);
      let tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "AccountSubscriptionCostUpdated")
        .withArgs(FIRST.address, await paymentToken.getAddress(), paymentTokenSubscriptionCost);

      tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx).to.not.emit(subscriptionManager, "AccountSubscriptionCostUpdated");

      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
    });

    it("should get exception if payment token is not available", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, newToken, basePeriodDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAvailableForPayment")
        .withArgs(await newToken.getAddress());
    });

    it("should get exception if passed account is not a vault", async () => {
      await expect(subscriptionManager.connect(FIRST).buySubscription(SECOND, ETHER_ADDR, basePeriodDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(SECOND.address);
    });

    it("should get exception if pass duration that less than the base period", async () => {
      const invalidDuration = basePeriodDuration / 2n;

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, ETHER_ADDR, invalidDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "InvalidSubscriptionDuration")
        .withArgs(invalidDuration);
    });
  });

  describe("#buySubscriptionWithSBT", () => {
    const tokenId = 1n;

    beforeEach("setup", async () => {
      await sbtToken.mint(FIRST, tokenId);
    });

    it("should correctly buy subscription with SBT token", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + sbtSubscriptionTime;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.connect(FIRST).buySubscriptionWithSBT(FIRST, sbtToken, tokenId);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSBT")
        .withArgs(await sbtToken.getAddress(), FIRST.address, tokenId);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, sbtSubscriptionTime, expectedEndTime);

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;
      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await expect(sbtToken.ownerOf(tokenId))
        .to.be.revertedWithCustomError(sbtToken, "ERC721NonexistentToken")
        .withArgs(tokenId);
    });

    it("should correctly extend subscription with SBT token", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      const duration = basePeriodDuration * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await subscriptionManager.connect(FIRST).buySubscriptionWithSBT(FIRST, sbtToken, tokenId);

      expect(await subscriptionManager.getAccountSubscriptionEndTime(FIRST)).to.be.eq(
        expectedEndTime + sbtSubscriptionTime,
      );
    });

    it("should get exception if pass unsupported SBT token address", async () => {
      const newSbtToken = await ethers.deployContract("SBTMock");
      await newSbtToken.mint(FIRST, tokenId);

      await expect(subscriptionManager.buySubscriptionWithSBT(FIRST, newSbtToken, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotSupportedSBT")
        .withArgs(await newSbtToken.getAddress());
    });

    it("should get exception if pass not a vault address", async () => {
      await expect(subscriptionManager.buySubscriptionWithSBT(FIRST, sbtToken, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });

    it("should get exception if pass invalid token id", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      await expect(subscriptionManager.connect(SECOND).buySubscriptionWithSBT(FIRST, sbtToken, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotATokenOwner")
        .withArgs(await sbtToken.getAddress(), SECOND.address, tokenId);
    });
  });

  describe("#buySubscriptionWithSignature", () => {
    it("should correctly buy subscription with signature", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      const duration = basePeriodDuration * 12n;

      const currentNonce = await subscriptionManager.nonces(OWNER);
      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: currentNonce,
      });

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscriptionWithSignature(FIRST, duration, signature);

      expect(await subscriptionManager.nonces(OWNER)).to.be.eq(currentNonce + 1n);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSignature")
        .withArgs(OWNER.address, duration, currentNonce);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);
    });

    it("should get exception if pass not a vault address", async () => {
      const currentNonce = await subscriptionManager.nonces(FIRST);
      const signature = await getBuySubscriptionSignature(subscriptionManager, FIRST, {
        sender: FIRST.address,
        duration: basePeriodDuration * 12n,
        nonce: currentNonce,
      });

      await expect(subscriptionManager.buySubscriptionWithSignature(FIRST, basePeriodDuration * 12n, signature))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateVaultName", () => {
    let vaultAddress1: AddressLike;
    let vaultAddress2: AddressLike;

    const updateVaultName = async (vault: AddressLike, token: ERC20Mock, name: string, signature: string) => {
      return await subscriptionManager["updateVaultName(address,address,string,bytes)"](vault, token, name, signature);
    };

    beforeEach("setup", async () => {
      const vault1 = await ethers.deployContract("VaultMock", [OWNER.address]);
      const vault2 = await ethers.deployContract("VaultMock", [FIRST.address]);

      await vaultFactory.setDeployedVault(vault1, true);
      await vaultFactory.setDeployedVault(vault2, true);

      vaultAddress1 = await vault1.getAddress();
      vaultAddress2 = await vault2.getAddress();
    });

    it("should correctly set vault name on the vault without the name", async () => {
      const vaultNameCost = paymentTokenVaultNameCost * threeLetterFactor;

      await paymentToken.mint(OWNER, vaultNameCost + paymentTokenSubscriptionCost);
      await paymentToken
        .connect(OWNER)
        .approve(await subscriptionManager.getAddress(), vaultNameCost + paymentTokenSubscriptionCost);

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePeriodDuration);

      const signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "abc",
        nonce: 0n,
      });

      const tx = await updateVaultName(vaultAddress1, paymentToken, "abc", signature);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress1, "abc");

      expect(await subscriptionManager.getVault("abc")).to.be.eq(vaultAddress1);
      expect(await subscriptionManager.getVaultName(vaultAddress1)).to.be.eq("abc");

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-vaultNameCost, vaultNameCost],
      );
    });

    it("should correctly update the vault name", async () => {
      const vaultNameCost1 = paymentTokenVaultNameCost;
      const vaultNameCost2 = paymentTokenVaultNameCost * threeLetterFactor;

      const totalAmountToPay = vaultNameCost1 + vaultNameCost2 + paymentTokenSubscriptionCost;

      await paymentToken.mint(OWNER, totalAmountToPay);
      await paymentToken.connect(OWNER).approve(await subscriptionManager.getAddress(), totalAmountToPay);

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePeriodDuration);

      let signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "abcdefg",
        nonce: 0n,
      });

      let tx = await updateVaultName(vaultAddress1, paymentToken, "abcdefg", signature);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress1, "abcdefg");

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-vaultNameCost1, vaultNameCost1],
      );

      signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "cba",
        nonce: 1n,
      });

      tx = await updateVaultName(vaultAddress1, paymentToken, "cba", signature);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress1, "cba");

      expect(await subscriptionManager.getVault("cba")).to.be.eq(vaultAddress1);
      expect(await subscriptionManager.getVaultName(vaultAddress1)).to.be.eq("cba");

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-vaultNameCost2, vaultNameCost2],
      );
    });

    it("should correctly update the vault name to already taken but available name", async () => {
      const vaultNameCost = paymentTokenVaultNameCost * fourLetterFactor;

      await paymentToken.mint(OWNER, vaultNameCost + paymentTokenSubscriptionCost);
      await paymentToken.approve(subscriptionManager, vaultNameCost + paymentTokenSubscriptionCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + basePeriodDuration;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePeriodDuration);

      let signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "abcd",
        nonce: 0n,
      });
      let tx = await updateVaultName(vaultAddress1, paymentToken, "abcd", signature);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress1, "abcd");

      expect(await subscriptionManager.isVaultNameAvailable("abcd")).to.be.false;

      await time.increaseTo(expectedEndTime + vaultNameRetentionPeriod + 1n);

      expect(await subscriptionManager.isVaultNameAvailable("abcd")).to.be.true;

      await paymentToken.mint(FIRST, vaultNameCost + paymentTokenSubscriptionCost);
      await paymentToken.connect(FIRST).approve(subscriptionManager, vaultNameCost + paymentTokenSubscriptionCost);

      await subscriptionManager.connect(FIRST).buySubscription(vaultAddress2, paymentToken, basePeriodDuration);

      signature = await getUpdateVaultNameSignature(subscriptionManager, FIRST, {
        account: vaultAddress2.toString(),
        vaultName: "abcd",
        nonce: 0n,
      });
      tx = await updateVaultName(vaultAddress2, paymentToken, "abcd", signature);

      await expect(tx)
        .to.emit(subscriptionManager, "VaultNameReassigned")
        .withArgs("abcd", vaultAddress1, vaultAddress2);
      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress2, "abcd");

      expect(await subscriptionManager.getVaultName(vaultAddress1)).to.be.eq("");

      expect(await subscriptionManager.getVault("abcd")).to.be.eq(vaultAddress2);
      expect(await subscriptionManager.getVaultName(vaultAddress2)).to.be.eq("abcd");
    });

    it("should get exception if the signer is not the vault owner", async () => {
      await paymentToken.mint(OWNER, paymentTokenSubscriptionCost);
      await paymentToken.connect(OWNER).approve(await subscriptionManager.getAddress(), paymentTokenSubscriptionCost);

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePeriodDuration);

      const signature = await getUpdateVaultNameSignature(subscriptionManager, FIRST, {
        account: vaultAddress1.toString(),
        vaultName: "abc",
        nonce: 0n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "abc", signature)).to.be.revertedWithCustomError(
        subscriptionManager,
        "InvalidSignature",
      );
    });

    it("should get exception if unavailable token is chosen to pay for the name", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);

      await expect(updateVaultName(vaultAddress1, newToken, "abcd", "0x"))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAvailableForPayment")
        .withArgs(await newToken.getAddress());

      await expect(subscriptionManager["updateVaultName(address,address,string)"](vaultAddress1, newToken, "abcd"))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAvailableForPayment")
        .withArgs(await newToken.getAddress());
    });

    it("should get exception if the account provided is not the vault", async () => {
      await expect(updateVaultName(FIRST, paymentToken, "abc", "0x")).to.be.revertedWithCustomError(
        subscriptionManager,
        "NotAVault",
      );

      await expect(
        subscriptionManager["updateVaultName(address,address,string)"](FIRST, paymentToken, "abc"),
      ).to.be.revertedWithCustomError(subscriptionManager, "NotAVault");
    });

    it("should get exception if the provided name is the same as the current one", async () => {
      const vaultNameCost = paymentTokenVaultNameCost * threeLetterFactor;

      await paymentToken.mint(OWNER, vaultNameCost * 2n + paymentTokenSubscriptionCost);
      await paymentToken
        .connect(OWNER)
        .approve(await subscriptionManager.getAddress(), vaultNameCost * 2n + paymentTokenSubscriptionCost);

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePeriodDuration);

      let signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "123",
        nonce: 0n,
      });

      await updateVaultName(vaultAddress1, paymentToken, "123", signature);

      signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "123",
        nonce: 1n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "123", signature))
        .to.be.revertedWithCustomError(subscriptionManager, "VaultNameUnchanged")
        .withArgs("123");
    });

    it("should get exception if the name is too short", async () => {
      let signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "ab",
        nonce: 0n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "ab", signature))
        .to.be.revertedWithCustomError(subscriptionManager, "VaultNameTooShort")
        .withArgs("ab");

      signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "",
        nonce: 0n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "", signature))
        .to.be.revertedWithCustomError(subscriptionManager, "VaultNameTooShort")
        .withArgs("");
    });

    it("should get exception if the vault does not have an active subscription", async () => {
      let signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "abc",
        nonce: 0n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "abc", signature))
        .to.be.revertedWithCustomError(subscriptionManager, "InactiveVaultSubscription")
        .withArgs(vaultAddress1);
    });

    it("should get exception if the name is unavailable", async () => {
      const vaultNameCost = paymentTokenVaultNameCost * fourLetterFactor;

      await paymentToken.mint(FIRST, vaultNameCost + paymentTokenSubscriptionCost);
      await paymentToken.connect(FIRST).approve(subscriptionManager, vaultNameCost + paymentTokenSubscriptionCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + basePeriodDuration;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.connect(FIRST).buySubscription(vaultAddress2, paymentToken, basePeriodDuration);

      let signature = await getUpdateVaultNameSignature(subscriptionManager, FIRST, {
        account: vaultAddress2.toString(),
        vaultName: "4321",
        nonce: 0n,
      });
      await updateVaultName(vaultAddress2, paymentToken, "4321", signature);

      await paymentToken.mint(OWNER, vaultNameCost + paymentTokenSubscriptionCost * 2n);
      await paymentToken
        .connect(OWNER)
        .approve(await subscriptionManager.getAddress(), vaultNameCost + paymentTokenSubscriptionCost * 2n);

      await subscriptionManager.connect(OWNER).buySubscription(vaultAddress1, paymentToken, basePeriodDuration * 2n);

      await time.setNextBlockTimestamp(expectedEndTime + vaultNameRetentionPeriod);

      signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "4321",
        nonce: 0n,
      });

      await expect(updateVaultName(vaultAddress1, paymentToken, "4321", signature))
        .to.be.revertedWithCustomError(subscriptionManager, "VaultNameAlreadyTaken")
        .withArgs("4321");
    });

    it("should get exception if the update function w/o signature is not called by the VaultFactory", async () => {
      await expect(subscriptionManager["updateVaultName(address,address,string)"](vaultAddress1, paymentToken, "abc"))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVaultFactory")
        .withArgs(OWNER.address);
    });
  });

  describe("#getSubscriptionCost", () => {
    it("should correctly count subscription cost for different periods", async () => {
      let duration = basePeriodDuration * 3n;
      let expectedCost = paymentTokenSubscriptionCost * 3n;

      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);

      duration = basePeriodDuration * 5n + basePeriodDuration / 2n;
      expectedCost = paymentTokenSubscriptionCost * 5n + paymentTokenSubscriptionCost / 2n;

      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost using stored account price", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      let duration = basePeriodDuration * 3n;
      let expectedCost = paymentTokenSubscriptionCost * 3n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      expect(await subscriptionManager.getBaseSubscriptionCostForAccount(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      const newPaymentTokenSubscriptionCost = paymentTokenSubscriptionCost * 2n;

      await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await paymentToken.getAddress(),
          baseSubscriptionCost: newPaymentTokenSubscriptionCost,
          baseVaultNameCost: paymentTokenVaultNameCost,
        },
      ]);

      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );

      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost when current cost < stored cost", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      let duration = basePeriodDuration * 3n;
      let expectedCost = paymentTokenSubscriptionCost * 3n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      expect(await subscriptionManager.getBaseSubscriptionCostForAccount(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      const newPaymentTokenSubscriptionCost = paymentTokenSubscriptionCost / 2n;

      await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await paymentToken.getAddress(),
          baseSubscriptionCost: newPaymentTokenSubscriptionCost,
          baseVaultNameCost: paymentTokenVaultNameCost,
        },
      ]);

      expect(await subscriptionManager.getBaseSubscriptionCostForAccount(FIRST, paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );

      expectedCost = newPaymentTokenSubscriptionCost * 3n;

      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost with duration factor", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      const duration = basePeriodDuration * 12n;
      const factor = PRECISION * 95n;

      const expectedCostWithoutFactor = paymentTokenSubscriptionCost * 12n;
      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithoutFactor,
      );

      await subscriptionManager.updateSubscriptionDurationFactor(duration, factor);

      const expectedCostWithFactor = (expectedCostWithoutFactor * factor) / PERCENTAGE_100;
      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithFactor,
      );

      await paymentToken.mint(OWNER, expectedCostWithFactor);
      await paymentToken.approve(subscriptionManager, expectedCostWithFactor);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await time.increaseTo(expectedEndTime + 100n);

      expect(await subscriptionManager.hasSubscriptionDebt(FIRST)).to.be.true;

      expect(await subscriptionManager.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithoutFactor,
      );
    });

    it("should get exception if pass zero duration", async () => {
      await expect(subscriptionManager.getSubscriptionCost(FIRST, paymentToken, 0n)).to.be.revertedWithCustomError(
        subscriptionManager,
        "ZeroDuration",
      );
    });

    it("should get exception if pass unsupported token address", async () => {
      await expect(subscriptionManager.getSubscriptionCost(FIRST, sbtToken, basePeriodDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotConfigured")
        .withArgs(await sbtToken.getAddress());
    });
  });
});
