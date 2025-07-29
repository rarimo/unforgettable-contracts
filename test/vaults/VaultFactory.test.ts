import { ERC20Mock, Vault, VaultFactory, VaultSubscriptionManager } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("VaultFactory", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  let OWNER: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let vaultImpl: Vault;
  let vaultFactoryImpl: VaultFactory;
  let vaultFactory: VaultFactory;
  let subscriptionManager: VaultSubscriptionManager;

  let paymentToken: ERC20Mock;

  before(async () => {
    [OWNER, SUBSCRIPTION_SIGNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    vaultImpl = await ethers.deployContract("Vault");
    vaultFactoryImpl = await ethers.deployContract("VaultFactory");

    const vaultFactoryInitData = vaultFactoryImpl.interface.encodeFunctionData("initialize(address)", [
      await vaultImpl.getAddress(),
    ]);
    const vaultFactoryProxy = await ethers.deployContract("ERC1967Proxy", [
      await vaultFactoryImpl.getAddress(),
      vaultFactoryInitData,
    ]);

    vaultFactory = await ethers.getContractAt("VaultFactory", await vaultFactoryProxy.getAddress());

    const subscriptionManagerImpl = await ethers.deployContract("VaultSubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(uint64,uint64,address,(address,uint256, uint256)[],(address,uint64)[])",
      [
        basePeriodDuration,
        3600n * 24n,
        SUBSCRIPTION_SIGNER.address,
        [
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
            baseVaultNameCost: nativeSubscriptionCost,
          },
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
            baseVaultNameCost: paymentTokenSubscriptionCost,
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
      "VaultSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    await vaultFactory.secondStepInitialize(await subscriptionManagerProxy.getAddress());
    await subscriptionManager.secondStepInitialize(await vaultFactoryProxy.getAddress());

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

      await expect(vaultFactory.initialize(vaultImpl2)).to.be.revertedWithCustomError(
        vaultFactory,
        "InvalidInitialization",
      );
    });

    it("should get exception if not an owner try to call secondStepInitialize function", async () => {
      await expect(vaultFactory.connect(FIRST).secondStepInitialize(FIRST))
        .to.be.revertedWithCustomError(vaultFactory, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });

    it("should get exception if try to call secondStepInitialize function twice", async () => {
      await expect(vaultFactory.secondStepInitialize(FIRST)).to.be.revertedWithCustomError(
        vaultFactory,
        "InvalidInitialization",
      );
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
    const initialSubscriptionDuration = basePeriodDuration * 12n;

    it("should correctly deploy new vault and buy subscription with ERC20 tokens", async () => {
      const creatorNonce = await vaultFactory.nonces(FIRST);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(vaultImpl, FIRST, creatorNonce);

      const expectedSubscriptionCost = await subscriptionManager.getSubscriptionCost(
        expectedVaultAddr,
        paymentToken,
        initialSubscriptionDuration,
      );
      const expectedVaultNameCost = await subscriptionManager.getVaultNameCost(paymentToken, "abc");

      const expectedTotalCost = expectedSubscriptionCost + expectedVaultNameCost;

      await paymentToken.connect(FIRST).approve(vaultFactory, expectedTotalCost);
      const tx = await vaultFactory
        .connect(FIRST)
        .deployVault(MASTER_KEY1, paymentToken, initialSubscriptionDuration, "abc");

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(FIRST.address, expectedVaultAddr, MASTER_KEY1.address);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(expectedVaultAddr, "abc");

      expect(await vaultFactory.getVaultCountByCreator(FIRST)).to.be.eq(1);
      expect(await vaultFactory.getVaultsByCreatorPart(FIRST, 0, 10)).to.be.deep.eq([expectedVaultAddr]);
      expect(await vaultFactory.isVault(expectedVaultAddr)).to.be.true;

      const deployedVault = await ethers.getContractAt("Vault", expectedVaultAddr);

      expect(await deployedVault.owner()).to.be.eq(MASTER_KEY1);

      expect(await subscriptionManager.getVault("abc")).to.be.eq(expectedVaultAddr);
      expect(await subscriptionManager.getVaultName(expectedVaultAddr)).to.be.eq("abc");

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [FIRST, subscriptionManager],
        [-expectedTotalCost, expectedTotalCost],
      );

      expect(await subscriptionManager.hasActiveSubscription(expectedVaultAddr)).to.be.true;
    });

    it("should correctly deploy new vault and buy subscription with native currency", async () => {
      const creatorNonce = await vaultFactory.nonces(FIRST);
      const expectedVaultAddr = await vaultFactory.predictVaultAddress(vaultImpl, FIRST, creatorNonce);

      const expectedSubscriptionCost = await subscriptionManager.getSubscriptionCost(
        expectedVaultAddr,
        ETHER_ADDR,
        initialSubscriptionDuration,
      );
      const expectedVaultNameCost = await subscriptionManager.getVaultNameCost(ETHER_ADDR, "1234");

      const expectedTotalCost = expectedSubscriptionCost + expectedVaultNameCost;

      const tx = await vaultFactory
        .connect(FIRST)
        .deployVault(MASTER_KEY1, ETHER_ADDR, initialSubscriptionDuration, "1234", { value: expectedTotalCost });

      await expect(tx)
        .to.emit(vaultFactory, "VaultDeployed")
        .withArgs(FIRST.address, expectedVaultAddr, MASTER_KEY1.address);

      await expect(tx).to.emit(subscriptionManager, "VaultNameUpdated").withArgs(expectedVaultAddr, "1234");

      await expect(tx).to.changeEtherBalances([FIRST, subscriptionManager], [-expectedTotalCost, expectedTotalCost]);
    });
  });
});
