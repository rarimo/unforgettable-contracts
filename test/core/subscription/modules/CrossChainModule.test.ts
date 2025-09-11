import { CrossChainModuleMock, SubscriptionsSynchronizerMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("CrossChainModule", () => {
  const reverter = new Reverter();

  let FIRST: SignerWithAddress;

  let crossChainModule: CrossChainModuleMock;
  let subscriptionsSynchronizer: SubscriptionsSynchronizerMock;

  beforeEach(async () => {
    [, FIRST] = await ethers.getSigners();

    subscriptionsSynchronizer = await ethers.deployContract("SubscriptionsSynchronizerMock");
    crossChainModule = await ethers.deployContract("CrossChainModuleMock");

    await crossChainModule.initialize({
      subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
    });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await crossChainModule.getSubscriptionsSynchronizer()).to.be.eq(
        await subscriptionsSynchronizer.getAddress(),
      );
    });

    it("should get exception if try to call init function directly", async () => {
      await expect(
        crossChainModule.__CrossChainModule_init({
          subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
        }),
      ).to.be.revertedWithCustomError(crossChainModule, "NotInitializing");
    });

    it("should get exception if try to initialize with zero address", async () => {
      const newCrossChainModule = await ethers.deployContract("CrossChainModuleMock");

      await expect(
        newCrossChainModule.initialize({
          subscriptionsSynchronizer: ethers.ZeroAddress,
        }),
      )
        .to.be.revertedWithCustomError(newCrossChainModule, "ZeroAddr")
        .withArgs("SubscriptionsSynchronizer");
    });
  });

  describe("#setSubscriptionSynchronizer", () => {
    it("should correctly update subscription synchronizer", async () => {
      const tx = await crossChainModule.setSubscriptionSynchronizer(FIRST);

      await expect(tx).to.emit(crossChainModule, "SubscriptionSynchronizerUpdated").withArgs(FIRST);
    });

    it("should get exception if try to set zero address", async () => {
      await expect(crossChainModule.setSubscriptionSynchronizer(ethers.ZeroAddress))
        .to.be.revertedWithCustomError(crossChainModule, "ZeroAddr")
        .withArgs("SubscriptionsSynchronizer");
    });
  });

  describe("#extendSubscription", () => {
    it("should correctly extend subscription and sync data", async () => {
      const duration = 3600n * 24n * 30n; // 30 days
      const expectedStartTime = BigInt(await time.latest()) + 100n;
      const expectedEndTime = expectedStartTime + duration;

      expect(await crossChainModule.getSubscriptionStartTime(FIRST)).to.be.eq(0n);
      expect(await crossChainModule.getSubscriptionEndTime(FIRST)).to.be.eq(await time.latest());
      expect(await crossChainModule.hasSubscription(FIRST)).to.be.false;
      expect(await crossChainModule.hasActiveSubscription(FIRST)).to.be.false;

      await time.setNextBlockTimestamp(expectedStartTime);
      const tx = await crossChainModule.extendSubscription(FIRST, duration);

      await expect(tx)
        .to.emit(crossChainModule, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);

      expect(await crossChainModule.getSubscriptionStartTime(FIRST)).to.be.eq(expectedStartTime);
      expect(await crossChainModule.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
      expect(await crossChainModule.hasSubscription(FIRST)).to.be.true;
      expect(await crossChainModule.hasActiveSubscription(FIRST)).to.be.true;
      expect(await crossChainModule.hasSubscriptionDebt(FIRST)).to.be.false;
    });
  });
});
