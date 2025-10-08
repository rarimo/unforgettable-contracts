import {
  ERC20Mock,
  SBTMock,
  SubscriptionsSynchronizer,
  Vault,
  VaultFactory,
  VaultSubscriptionManager,
} from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter, getBuySubscriptionSignature } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("VaultFactory", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  const defaultVaultName = "NewVaultName";

  let OWNER: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let vaultImpl: Vault;
  let vaultFactoryImpl: VaultFactory;
  let vaultFactory: VaultFactory;
  let subscriptionManager: VaultSubscriptionManager;

  let subscriptionsSynchronizer: SubscriptionsSynchronizer;

  let paymentToken: ERC20Mock;

  let sbt: SBTMock;

  before(async () => {
    [OWNER, SUBSCRIPTION_SIGNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    sbt = await ethers.deployContract("SBTMock");

    vaultImpl = await ethers.deployContract("Vault");
    vaultFactoryImpl = await ethers.deployContract("VaultFactory");

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

    await sbt.initialize("TestSBT", "TSBT", [subscriptionManager]);

    await vaultFactory.initialize(vaultImpl, subscriptionManager);
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
        discountEntries: [],
      },
      sbtPaymentInitData: {
        sbtEntries: [
          {
            sbt: sbt,
            subscriptionDurationPerToken: basePaymentPeriod,
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

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await vaultFactory.owner()).to.be.eq(OWNER);
      expect(await vaultFactory.implementation()).to.be.eq(vaultFactoryImpl);
      expect(await vaultFactory.getVaultImplementation()).to.be.eq(vaultImpl);
      expect(await vaultFactory.getVaultSubscriptionManager()).to.be.eq(subscriptionManager);
    });

    it("should get exception if try to call init function twice", async () => {
      const vaultImpl2 = await ethers.deployContract("Vault");

      await expect(vaultFactory.initialize(vaultImpl2, subscriptionManager)).to.be.revertedWithCustomError(
        vaultFactory,
        "InvalidInitialization",
      );
    });

    it("should get exception if not a deployer try to call init function", async () => {
      const vaultFactoryProxy = await ethers.deployContract("ERC1967Proxy", [
        await vaultFactoryImpl.getAddress(),
        "0x",
      ]);

      const vaultFactory = await ethers.getContractAt("VaultFactory", await vaultFactoryProxy.getAddress());

      await expect(vaultFactory.connect(FIRST).initialize(FIRST, SECOND))
        .to.be.revertedWithCustomError(vaultFactory, "OnlyDeployer")
        .withArgs(FIRST.address);
    });
  });

  describe("#upgrade", () => {
    it("should correctly upgrade VaultFactory contract", async () => {
      const newVaultFactoryImpl = await ethers.deployContract("VaultFactoryMock");

      const vaultFactoryMock = await ethers.getContractAt("VaultFactoryMock", vaultFactory);

      await expect(vaultFactoryMock.version()).to.be.revertedWithoutReason();

      await vaultFactory.upgradeToAndCall(newVaultFactoryImpl, "0x");

      expect(await vaultFactory.implementation()).to.be.eq(newVaultFactoryImpl);

      expect(await vaultFactoryMock.version()).to.be.eq("v2.0.0");
    });

    it("should get exception if not an owner try to upgrade VaultFactory", async () => {
      const newVaultFactoryImpl = await ethers.deployContract("VaultFactoryMock");

      await expect(vaultFactory.connect(FIRST).upgradeToAndCall(newVaultFactoryImpl, "0x"))
        .to.be.revertedWithCustomError(vaultFactory, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateVaultImplementation", () => {
    it("should correctly update vault implementation", async () => {
      const newVaultImpl = await ethers.deployContract("Vault");

      const tx = await vaultFactory.updateVaultImplementation(newVaultImpl);

      expect(await vaultFactory.getVaultImplementation()).to.be.eq(newVaultImpl);

      await expect(tx)
        .to.emit(vaultFactory, "VaultImplementationUpdated")
        .withArgs(await newVaultImpl.getAddress());
    });

    it("should get exception if pass zero address", async () => {
      await expect(vaultFactory.updateVaultImplementation(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        vaultFactory,
        "ZeroAddress",
      );
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(vaultFactory.connect(FIRST).updateVaultImplementation(FIRST))
        .to.be.revertedWithCustomError(vaultFactory, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateTokenLimitAmount", () => {
    it("should correctly update token limit amount", async () => {
      let newPaymentTokenLimitAmount = wei(500);

      expect(await vaultFactory.getTokenLimitAmount(paymentToken)).to.be.eq(0);

      const tx = await vaultFactory.updateTokenLimitAmount(paymentToken, newPaymentTokenLimitAmount);

      expect(await vaultFactory.getTokenLimitAmount(paymentToken)).to.be.eq(newPaymentTokenLimitAmount);

      await expect(tx)
        .to.emit(vaultFactory, "TokenLimitAmountUpdated")
        .withArgs(await paymentToken.getAddress(), newPaymentTokenLimitAmount);

      newPaymentTokenLimitAmount = wei(750);

      await vaultFactory.updateTokenLimitAmount(paymentToken, newPaymentTokenLimitAmount);

      expect(await vaultFactory.getTokenLimitAmount(paymentToken)).to.be.eq(newPaymentTokenLimitAmount);

      newPaymentTokenLimitAmount = 0n;

      await vaultFactory.updateTokenLimitAmount(paymentToken, newPaymentTokenLimitAmount);

      expect(await vaultFactory.getTokenLimitAmount(paymentToken)).to.be.eq(newPaymentTokenLimitAmount);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(vaultFactory.connect(FIRST).updateTokenLimitAmount(paymentToken, wei(100000)))
        .to.be.revertedWithCustomError(vaultFactory, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#deployVault", () => {
    const initialSubscriptionDuration = basePaymentPeriod * 12n;

    it("should correctly deploy new vault and buy subscription with ERC20 tokens", async () => {
      const masterKeyNonce = await vaultFactory.nonces(MASTER_KEY1);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(MASTER_KEY1, masterKeyNonce);

      const expectedSubscriptionCost = await subscriptionManager.getSubscriptionCost(
        expectedVaultAddr,
        paymentToken,
        initialSubscriptionDuration,
      );

      expect(await vaultFactory.isVault(expectedVaultAddr)).to.be.false;

      await paymentToken.connect(FIRST).approve(vaultFactory, expectedSubscriptionCost);
      const tx = await vaultFactory
        .connect(FIRST)
        .deployVault(MASTER_KEY1, paymentToken, initialSubscriptionDuration, defaultVaultName);

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(FIRST.address, expectedVaultAddr, MASTER_KEY1.address, defaultVaultName);

      expect(await vaultFactory.getVaultCountByCreator(FIRST)).to.be.eq(1);
      expect(await vaultFactory.getVaultsByCreatorPart(FIRST, 0, 10)).to.be.deep.eq([expectedVaultAddr]);
      expect(await vaultFactory.isVault(expectedVaultAddr)).to.be.true;

      const deployedVault = await ethers.getContractAt("Vault", expectedVaultAddr);

      expect(await deployedVault.owner()).to.be.eq(MASTER_KEY1);

      expect(await vaultFactory.getVaultByName(defaultVaultName)).to.be.eq(expectedVaultAddr);
      expect(await vaultFactory.getVaultName(expectedVaultAddr)).to.be.eq(defaultVaultName);

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [FIRST, subscriptionManager],
        [-expectedSubscriptionCost, expectedSubscriptionCost],
      );

      expect(await subscriptionManager.hasActiveSubscription(expectedVaultAddr)).to.be.true;
    });

    it("should correctly deploy new vault and buy subscription with native currency", async () => {
      const masterKeyNonce = await vaultFactory.nonces(MASTER_KEY1);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(MASTER_KEY1, masterKeyNonce);

      const expectedSubscriptionCost = await subscriptionManager.getSubscriptionCost(
        expectedVaultAddr,
        ETHER_ADDR,
        initialSubscriptionDuration,
      );

      const tx = await vaultFactory
        .connect(FIRST)
        .deployVault(MASTER_KEY1, ETHER_ADDR, initialSubscriptionDuration, defaultVaultName, {
          value: expectedSubscriptionCost,
        });

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(FIRST.address, expectedVaultAddr, MASTER_KEY1.address, defaultVaultName);

      await expect(tx).to.changeEtherBalances(
        [FIRST, subscriptionManager],
        [-expectedSubscriptionCost, expectedSubscriptionCost],
      );
    });

    it("should correctly deploy new vault and buy subscription with signature", async () => {
      const masterKeyNonce = await vaultFactory.nonces(MASTER_KEY1);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(MASTER_KEY1, masterKeyNonce);

      const sig = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: SECOND.address,
        duration: initialSubscriptionDuration,
        nonce: await subscriptionManager.nonces(SECOND),
      });

      const tx = await vaultFactory
        .connect(SECOND)
        .deployVaultWithSignature(MASTER_KEY1, initialSubscriptionDuration, sig, defaultVaultName);

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(SECOND.address, expectedVaultAddr, MASTER_KEY1.address, defaultVaultName);

      await expect(tx).to.changeTokenBalances(paymentToken, [SECOND, subscriptionManager], [0, 0]);
    });

    it("should correctly deploy new vault and buy subscription with sbt", async () => {
      const tokenId = 123;
      await sbt.mint(SECOND, tokenId);

      const masterKeyNonce = await vaultFactory.nonces(MASTER_KEY1);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(MASTER_KEY1, masterKeyNonce);

      const tx = await vaultFactory.connect(SECOND).deployVaultWithSBT(MASTER_KEY1, sbt, tokenId, defaultVaultName);

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(SECOND.address, expectedVaultAddr, MASTER_KEY1.address, defaultVaultName);

      await expect(tx).to.changeEtherBalances([SECOND, subscriptionManager], [0, 0]);
    });

    it("should get exception if try to deploy vault with not unique name", async () => {
      const tokenId1 = 123;
      const tokenId2 = 124;
      await sbt.mint(FIRST, tokenId1);
      await sbt.mint(SECOND, tokenId2);

      await vaultFactory.connect(FIRST).deployVaultWithSBT(MASTER_KEY1, sbt, tokenId1, defaultVaultName);

      expect(await vaultFactory.isVaultNameAvailable(defaultVaultName)).to.be.false;

      await expect(vaultFactory.connect(SECOND).deployVaultWithSBT(MASTER_KEY1, sbt, tokenId2, defaultVaultName))
        .to.be.revertedWithCustomError(vaultFactory, "VaultNameAlreadyTaken")
        .withArgs(defaultVaultName);
    });

    it("should get exception if pass short vault name", async () => {
      const tokenId = 123;
      await sbt.mint(SECOND, tokenId);

      const shortName = "abc";

      await expect(vaultFactory.connect(SECOND).deployVaultWithSBT(MASTER_KEY1, sbt, tokenId, shortName))
        .to.be.revertedWithCustomError(vaultFactory, "VaultNameTooShort")
        .withArgs(shortName);
    });
  });
});
