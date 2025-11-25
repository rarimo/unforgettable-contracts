import { ERC20Mock, HelperDataSubscriptionManager, SBTMock } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("HelperDataSubscriptionManager", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;
  const sbtSubscriptionDuration = basePaymentPeriod * 12n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;

  let subscriptionManagerImpl: HelperDataSubscriptionManager;
  let subscriptionManager: HelperDataSubscriptionManager;

  let paymentToken: ERC20Mock;
  let sbt: SBTMock;

  before(async () => {
    [OWNER, FIRST, SECOND, SUBSCRIPTION_SIGNER] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);
    sbt = await ethers.deployContract("SBTMock");

    await sbt.initialize("Mock SBT", "MSBT", [OWNER]);

    subscriptionManagerImpl = await ethers.deployContract("HelperDataSubscriptionManager");

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);
    subscriptionManager = await ethers.getContractAt(
      "HelperDataSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    await subscriptionManager.initialize({
      subscriptionCreators: [],
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
            sbt: await sbt.getAddress(),
            subscriptionDurationPerToken: sbtSubscriptionDuration,
          },
        ],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: SUBSCRIPTION_SIGNER,
      },
      crossChainInitData: {
        subscriptionsSynchronizer: ethers.ZeroAddress,
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
        "HelperDataSubscriptionManager",
        await subscriptionManagerProxy.getAddress(),
      );

      await expect(
        newSubscriptionManager.connect(FIRST).initialize({
          subscriptionCreators: [],
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
            discountEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
          crossChainInitData: {
            subscriptionsSynchronizer: ethers.ZeroAddress,
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
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
            discountEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
          crossChainInitData: {
            subscriptionsSynchronizer: ethers.ZeroAddress,
          },
        }),
      ).to.be.revertedWithCustomError(subscriptionManager, "InvalidInitialization");
    });
  });

  describe("#buySubscription", () => {
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

    it("should correctly buy and extend subscription", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost * 2n);
      await paymentToken.approve(subscriptionManager, expectedCost * 2n);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration * 2n;

      await time.setNextBlockTimestamp(startTime);
      let tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "AccountTokenSubscriptionCostUpdated")
        .withArgs(FIRST.address, await paymentToken.getAddress(), paymentTokenSubscriptionCost);

      tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx).to.not.emit(subscriptionManager, "AccountTokenSubscriptionCostUpdated");

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
    });

    it("should get exception if payment token is not available", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, newToken, basePaymentPeriod))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotSupported")
        .withArgs(await newToken.getAddress());
    });

    it("should get exception if pass duration that less than the base period", async () => {
      const invalidDuration = basePaymentPeriod / 2n;

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, ETHER_ADDR, invalidDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "InvalidSubscriptionDuration")
        .withArgs(invalidDuration);
    });

    it("should get exception if paused", async () => {
      await subscriptionManager.pause();

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, ETHER_ADDR, basePaymentPeriod))
        .to.be.revertedWithCustomError(subscriptionManager, "EnforcedPause")
        .withArgs();
    });
  });
});
