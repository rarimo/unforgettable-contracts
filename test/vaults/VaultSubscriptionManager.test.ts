import { ERC20Mock, SBTMock, SubscriptionsSynchronizer, VaultFactoryMock, VaultSubscriptionManager } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

import { getBuySubscriptionSignature } from "../helpers/sign-utils";

describe("VaultSubscriptionManager", () => {
  const reverter = new Reverter();

  const defaultVaultName = "MyVault";

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;
  const sbtSubscriptionDuration = basePaymentPeriod * 12n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  let OWNER: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;

  let vaultFactory: VaultFactoryMock;
  let subscriptionManagerImpl: VaultSubscriptionManager;
  let subscriptionManager: VaultSubscriptionManager;

  let subscriptionsSynchronizer: SubscriptionsSynchronizer;

  let paymentToken: ERC20Mock;
  let sbt: SBTMock;

  before(async () => {
    [OWNER, SUBSCRIPTION_SIGNER, FIRST, SECOND] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);
    sbt = await ethers.deployContract("SBTMock");

    await sbt.initialize("Mock SBT", "MSBT", [OWNER]);

    vaultFactory = await ethers.deployContract("VaultFactoryMock");

    subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManager");

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);
    subscriptionManager = await ethers.getContractAt(
      "VaultSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

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

    await subscriptionManager.initialize({
      subscriptionCreators: [],
      vaultFactoryAddr: await vaultFactory.getAddress(),
      tokensPaymentInitData: {
        basePaymentPeriod: basePaymentPeriod,
        durationFactorEntries: [],
        paymentTokenEntries: [
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
          },
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
      },
      sbtPaymentInitData: {
        sbtEntries: [
          {
            sbt: await sbt.getAddress(),
            subscriptionDurationPerToken: sbtSubscriptionDuration,
          },
        ],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: SUBSCRIPTION_SIGNER,
      },
      crossChainInitData: {
        subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
      },
    });

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await sbt.addOwners([subscriptionManager]);

    expect(await sbt.isOwner(subscriptionManager)).to.be.true;

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await subscriptionManager.owner()).to.be.eq(OWNER);
      expect(await subscriptionManager.implementation()).to.be.eq(subscriptionManagerImpl);
      expect(await subscriptionManager.getSubscriptionCreators()).to.be.deep.eq([]);
      expect(await subscriptionManager.getBasePaymentPeriod()).to.be.eq(basePaymentPeriod);
      expect(await subscriptionManager.getSubscriptionSigner()).to.be.eq(SUBSCRIPTION_SIGNER);
      expect(await subscriptionManager.getVaultFactory()).to.be.eq(vaultFactory);

      expect(await subscriptionManager.getPaymentTokens()).to.be.deep.eq([ETHER_ADDR, await paymentToken.getAddress()]);

      expect(await subscriptionManager.isSupportedToken(ETHER_ADDR)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(nativeSubscriptionCost);
      expect(await subscriptionManager.isSupportedToken(paymentToken)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      expect(await subscriptionManager.isSupportedSBT(sbt)).to.be.true;
      expect(await subscriptionManager.getSubscriptionDurationPerSBT(sbt)).to.be.eq(sbtSubscriptionDuration);
    });

    it("should get exception if not a deployer try to call init function", async () => {
      const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
        await subscriptionManagerImpl.getAddress(),
        "0x",
      ]);
      const newSubscriptionManager = await ethers.getContractAt(
        "VaultSubscriptionManager",
        await subscriptionManagerProxy.getAddress(),
      );

      await expect(
        newSubscriptionManager.connect(FIRST).initialize({
          subscriptionCreators: [],
          vaultFactoryAddr: await vaultFactory.getAddress(),
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
          crossChainInitData: {
            subscriptionsSynchronizer: ZeroAddress,
          },
        }),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OnlyDeployer")
        .withArgs(FIRST.address);
    });

    it("should get exception if try to call init function twice", async () => {
      await expect(
        subscriptionManager.initialize({
          subscriptionCreators: [],
          vaultFactoryAddr: await vaultFactory.getAddress(),
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
          crossChainInitData: {
            subscriptionsSynchronizer: ZeroAddress,
          },
        }),
      ).to.be.revertedWithCustomError(subscriptionManager, "InvalidInitialization");
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

    it("should get exception if not an owner try to upgrade VaultSubscriptionManager", async () => {
      const newSubscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManagerMock");

      await expect(subscriptionManager.connect(FIRST).upgradeToAndCall(newSubscriptionManagerImpl, "0x"))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscription", () => {
    beforeEach("setup", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);
    });

    it("should correctly buy subscription for 2 base periods", async () => {
      const duration = basePaymentPeriod * 2n;
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
        },
      ]);

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
      expect(await subscriptionManager.getAccountBaseSubscriptionCost(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost * 2n,
      );
    });

    it("should get exception if passed account is not a vault", async () => {
      await expect(subscriptionManager.connect(FIRST).buySubscription(SECOND, ETHER_ADDR, basePaymentPeriod))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(SECOND.address);
    });
  });

  describe("#buySubscriptionWithSBT", () => {
    const tokenId = 1n;

    beforeEach("setup", async () => {
      await sbt.mint(FIRST, tokenId);
    });

    it("should correctly buy subscription with SBT token", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + sbtSubscriptionDuration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager
        .connect(FIRST)
        ["buySubscriptionWithSBT(address,address,uint256)"](FIRST, sbt, tokenId);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSBT")
        .withArgs(await sbt.getAddress(), FIRST.address, tokenId);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, sbtSubscriptionDuration, expectedEndTime);

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;
      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await expect(sbt.ownerOf(tokenId)).to.be.revertedWithCustomError(sbt, "ERC721NonexistentToken").withArgs(tokenId);
    });

    it("should get exception if pass not a vault address", async () => {
      await expect(subscriptionManager["buySubscriptionWithSBT(address,address,uint256)"](FIRST, sbt, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscriptionWithSBT(with sbtOwner)", () => {
    const tokenId = 1n;

    beforeEach("setup", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      await sbt.mint(FIRST, tokenId);
    });

    it("should correctly buy subscription with SBT token", async () => {
      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + sbtSubscriptionDuration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, FIRST, sbt, FIRST, tokenId);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSBT")
        .withArgs(await sbt.getAddress(), FIRST.address, tokenId);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, sbtSubscriptionDuration, expectedEndTime);

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;
      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await expect(sbt.ownerOf(tokenId)).to.be.revertedWithCustomError(sbt, "ERC721NonexistentToken").withArgs(tokenId);
    });

    it("should get exception if paused", async () => {
      await subscriptionManager.pause();

      await expect(
        vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, FIRST, sbt, FIRST, tokenId),
      ).to.be.revertedWithCustomError(subscriptionManager, "EnforcedPause");
    });

    it("should get exception if pass not a vault address", async () => {
      await expect(vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, SECOND, sbt, FIRST, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(SECOND.address);
    });

    it("should get exception if pass unsupported sbt address", async () => {
      await expect(vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, FIRST, FIRST, FIRST, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotSupportedSBT")
        .withArgs(FIRST.address);
    });

    it("should get exception if the caller is not the vault factory", async () => {
      const newVaultFactory = await ethers.deployContract("VaultFactoryMock");

      await newVaultFactory.setVaultName(FIRST, defaultVaultName);

      const subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManagerMock");

      const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
        await subscriptionManagerImpl.getAddress(),
        "0x",
      ]);
      const subscriptionManager = await ethers.getContractAt(
        "VaultSubscriptionManagerMock",
        await subscriptionManagerProxy.getAddress(),
      );

      await subscriptionManager.initialize({
        subscriptionCreators: [],
        vaultFactoryAddr: await newVaultFactory.getAddress(),
        tokensPaymentInitData: {
          basePaymentPeriod: basePaymentPeriod,
          durationFactorEntries: [],
          paymentTokenEntries: [],
        },
        sbtPaymentInitData: {
          sbtEntries: [
            {
              sbt: await sbt.getAddress(),
              subscriptionDurationPerToken: sbtSubscriptionDuration,
            },
          ],
        },
        sigSubscriptionInitData: {
          subscriptionSigner: SUBSCRIPTION_SIGNER,
        },
        crossChainInitData: {
          subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
        },
      });

      await expect(vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, FIRST, sbt, FIRST, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVaultFactory")
        .withArgs(await vaultFactory.getAddress());
    });

    it("should get exception if the passed owner is not the sbt owner", async () => {
      await expect(vaultFactory.callBuySubscriptionWithSBT(subscriptionManager, FIRST, sbt, SECOND, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotASBTOwner")
        .withArgs(await sbt.getAddress(), SECOND.address, tokenId);
    });
  });

  describe("#buySubscriptionWithSignature", () => {
    it("should correctly buy subscription with signature", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      const duration = basePaymentPeriod * 12n;

      const currentNonce = await subscriptionManager.nonces(OWNER);
      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: currentNonce,
      });

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager["buySubscriptionWithSignature(address,uint64,bytes)"](
        FIRST,
        duration,
        signature,
      );

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
        duration: basePaymentPeriod * 12n,
        nonce: currentNonce,
      });

      await expect(
        subscriptionManager["buySubscriptionWithSignature(address,uint64,bytes)"](
          FIRST,
          basePaymentPeriod * 12n,
          signature,
        ),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscriptionWithSignature(with sender)", () => {
    it("should correctly buy subscription with signature", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      const duration = basePaymentPeriod * 12n;

      const currentNonce = await subscriptionManager.nonces(OWNER);
      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: currentNonce,
      });

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await vaultFactory.callBuySubscriptionWithSignature(
        subscriptionManager,
        OWNER,
        FIRST,
        duration,
        signature,
      );

      expect(await subscriptionManager.nonces(OWNER)).to.be.eq(currentNonce + 1n);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSignature")
        .withArgs(OWNER.address, duration, currentNonce);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);
    });

    it("should get exception if paused", async () => {
      await subscriptionManager.pause();
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      const duration = basePaymentPeriod * 12n;

      const currentNonce = await subscriptionManager.nonces(OWNER);
      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: currentNonce,
      });

      await expect(
        vaultFactory.callBuySubscriptionWithSignature(subscriptionManager, OWNER, FIRST, duration, signature),
      ).to.be.revertedWithCustomError(subscriptionManager, "EnforcedPause");
    });

    it("should get exception if pass not a vault address", async () => {
      const currentNonce = await subscriptionManager.nonces(FIRST);
      const signature = await getBuySubscriptionSignature(subscriptionManager, FIRST, {
        sender: FIRST.address,
        duration: basePaymentPeriod * 12n,
        nonce: currentNonce,
      });

      await expect(
        vaultFactory.callBuySubscriptionWithSignature(
          subscriptionManager,
          OWNER,
          FIRST,
          basePaymentPeriod * 12n,
          signature,
        ),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });

    it("should get exception if the caller is not the vault factory", async () => {
      const newVaultFactory = await ethers.deployContract("VaultFactoryMock");

      await newVaultFactory.setVaultName(OWNER, defaultVaultName);

      const subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManagerMock");

      const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
        await subscriptionManagerImpl.getAddress(),
        "0x",
      ]);
      const subscriptionManager = await ethers.getContractAt(
        "VaultSubscriptionManagerMock",
        await subscriptionManagerProxy.getAddress(),
      );

      await subscriptionManager.initialize({
        subscriptionCreators: [],
        vaultFactoryAddr: await newVaultFactory.getAddress(),
        tokensPaymentInitData: {
          basePaymentPeriod: basePaymentPeriod,
          durationFactorEntries: [],
          paymentTokenEntries: [],
        },
        sbtPaymentInitData: {
          sbtEntries: [
            {
              sbt: await sbt.getAddress(),
              subscriptionDurationPerToken: sbtSubscriptionDuration,
            },
          ],
        },
        sigSubscriptionInitData: {
          subscriptionSigner: SUBSCRIPTION_SIGNER,
        },
        crossChainInitData: {
          subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
        },
      });

      await expect(
        vaultFactory.callBuySubscriptionWithSignature(subscriptionManager, OWNER, OWNER, basePaymentPeriod * 12n, "0x"),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVaultFactory")
        .withArgs(await vaultFactory.getAddress());
    });

    it("should get exception if try to pass invalid sender", async () => {
      await vaultFactory.setVaultName(FIRST, defaultVaultName);

      const duration = basePaymentPeriod * 12n;

      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: await subscriptionManager.nonces(OWNER),
      });

      await expect(
        vaultFactory.callBuySubscriptionWithSignature(subscriptionManager, FIRST, FIRST, duration, signature),
      ).to.be.revertedWithCustomError(subscriptionManager, "InvalidSignature");
    });
  });
});
