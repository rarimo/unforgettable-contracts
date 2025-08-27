import { ERC20Mock, SBTMock, VaultFactoryMock, VaultSubscriptionManager } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
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
  const basePaymentPeriod = 3600n * 24n * 30n;
  const sbtSubscriptionDuration = basePaymentPeriod * 12n;

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

  let vaultFactory: VaultFactoryMock;
  let subscriptionManagerImpl: VaultSubscriptionManager;
  let subscriptionManager: VaultSubscriptionManager;

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

    await subscriptionManager.initialize({
      subscriptionCreators: [],
      vaultFactoryAddr: await vaultFactory.getAddress(),
      vaultNameRetentionPeriod: vaultNameRetentionPeriod,
      vaultPaymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseVaultNameCost: nativeVaultNameCost,
        },
        {
          paymentToken: await paymentToken.getAddress(),
          baseVaultNameCost: paymentTokenVaultNameCost,
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
      expect(await subscriptionManager.getVaultNameRetentionPeriod()).to.be.eq(vaultNameRetentionPeriod);
      expect(await subscriptionManager.getVaultFactory()).to.be.eq(vaultFactory);

      expect(await subscriptionManager.getPaymentTokens()).to.be.deep.eq([ETHER_ADDR, await paymentToken.getAddress()]);

      expect(await subscriptionManager.isSupportedToken(ETHER_ADDR)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(nativeSubscriptionCost);
      expect(await subscriptionManager.getTokenBaseVaultNameCost(ETHER_ADDR)).to.be.eq(nativeVaultNameCost);
      expect(await subscriptionManager.isSupportedToken(paymentToken)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseVaultNameCost(paymentToken)).to.be.eq(paymentTokenVaultNameCost);

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
          vaultNameRetentionPeriod: vaultNameRetentionPeriod,
          vaultPaymentTokenEntries: [],
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
          vaultNameRetentionPeriod: vaultNameRetentionPeriod,
          vaultPaymentTokenEntries: [],
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

  describe("#updateVaultPaymentTokens", () => {
    it("should correctly add new vault payment tokens", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);
      const vaultNameCost = wei(2);

      const tx = await subscriptionManager.updateVaultPaymentTokens([
        {
          paymentToken: await newToken.getAddress(),
          baseVaultNameCost: vaultNameCost,
        },
      ]);

      expect(await subscriptionManager.getTokenBaseVaultNameCost(await newToken.getAddress())).to.be.eq(vaultNameCost);

      await expect(tx)
        .to.emit(subscriptionManager, "VaultNameCostUpdated")
        .withArgs(await newToken.getAddress(), vaultNameCost);
    });

    it("should get exception if pass zero address", async () => {
      await expect(
        subscriptionManager.updateVaultPaymentTokens([
          {
            paymentToken: ethers.ZeroAddress,
            baseVaultNameCost: wei(2),
          },
        ]),
      ).to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr");
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updateVaultPaymentTokens([
          {
            paymentToken: FIRST.address,
            baseVaultNameCost: wei(2),
          },
        ]),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscription", () => {
    beforeEach("setup", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);
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
      await vaultFactory.setDeployedVault(FIRST, true);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + sbtSubscriptionDuration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.connect(FIRST).buySubscriptionWithSBT(FIRST, sbt, tokenId);

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
      await expect(subscriptionManager.buySubscriptionWithSBT(FIRST, sbt, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscriptionWithSBT(with sbtOwner)", () => {
    const tokenId = 1n;

    beforeEach("setup", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

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

      await newVaultFactory.setDeployedVault(FIRST, true);

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
        vaultNameRetentionPeriod: vaultNameRetentionPeriod,
        vaultPaymentTokenEntries: [],
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
      await vaultFactory.setDeployedVault(FIRST, true);

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
        duration: basePaymentPeriod * 12n,
        nonce: currentNonce,
      });

      await expect(subscriptionManager.buySubscriptionWithSignature(FIRST, basePaymentPeriod * 12n, signature))
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVault")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscriptionWithSignature(with sender)", () => {
    it("should correctly buy subscription with signature", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

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

      await newVaultFactory.setDeployedVault(OWNER, true);

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
        vaultNameRetentionPeriod: vaultNameRetentionPeriod,
        vaultPaymentTokenEntries: [],
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
      });

      await expect(
        vaultFactory.callBuySubscriptionWithSignature(subscriptionManager, OWNER, OWNER, basePaymentPeriod * 12n, "0x"),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "NotAVaultFactory")
        .withArgs(await vaultFactory.getAddress());
    });

    it("should get exception if try to pass invalid sender", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

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

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePaymentPeriod);

      const signature = await getUpdateVaultNameSignature(subscriptionManager, OWNER, {
        account: vaultAddress1.toString(),
        vaultName: "abc",
        nonce: 0n,
      });

      const tx = await updateVaultName(vaultAddress1, paymentToken, "abc", signature);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(vaultAddress1, "abc");

      expect(await subscriptionManager.getVaultByName("abc")).to.be.eq(vaultAddress1);
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

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePaymentPeriod);

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

      expect(await subscriptionManager.getVaultByName("cba")).to.be.eq(vaultAddress1);
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
      const expectedEndTime = BigInt(startTime) + basePaymentPeriod;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePaymentPeriod);

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

      await subscriptionManager.connect(FIRST).buySubscription(vaultAddress2, paymentToken, basePaymentPeriod);

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

      expect(await subscriptionManager.getVaultByName("abcd")).to.be.eq(vaultAddress2);
      expect(await subscriptionManager.getVaultName(vaultAddress2)).to.be.eq("abcd");
    });

    it("should get exception if the signer is not the vault owner", async () => {
      await paymentToken.mint(OWNER, paymentTokenSubscriptionCost);
      await paymentToken.connect(OWNER).approve(await subscriptionManager.getAddress(), paymentTokenSubscriptionCost);

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePaymentPeriod);

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
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotSupported")
        .withArgs(await newToken.getAddress());

      await expect(subscriptionManager["updateVaultName(address,address,string)"](vaultAddress1, newToken, "abcd"))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotSupported")
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

      await subscriptionManager.buySubscription(vaultAddress1, paymentToken, basePaymentPeriod);

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
      const expectedEndTime = BigInt(startTime) + basePaymentPeriod;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.connect(FIRST).buySubscription(vaultAddress2, paymentToken, basePaymentPeriod);

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

      await subscriptionManager.connect(OWNER).buySubscription(vaultAddress1, paymentToken, basePaymentPeriod * 2n);

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
});
