import { BaseSubscriptionModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("BaseSubscriptionModule", () => {
  const reverter = new Reverter();

  let FIRST: SignerWithAddress;

  let baseSubscriptionModule: BaseSubscriptionModuleMock;

  beforeEach(async () => {
    [FIRST] = await ethers.getSigners();

    baseSubscriptionModule = await ethers.deployContract("BaseSubscriptionModuleMock");

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#extendSubscription", () => {
    it("should correctly set start and end time", async () => {
      const duration = 123n;

      const expectedStartTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = expectedStartTime + duration;

      expect(await baseSubscriptionModule.getSubscriptionStartTime(FIRST)).to.be.eq(0n);
      expect(await baseSubscriptionModule.getSubscriptionEndTime(FIRST)).to.be.eq(await time.latest());

      expect(await baseSubscriptionModule.hasSubscription(FIRST)).to.be.false;
      expect(await baseSubscriptionModule.hasActiveSubscription(FIRST)).to.be.false;

      await time.setNextBlockTimestamp(expectedStartTime);
      const tx = await baseSubscriptionModule.extendSubscription(FIRST, duration);

      await expect(tx)
        .to.emit(baseSubscriptionModule, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);

      expect(await baseSubscriptionModule.getSubscriptionStartTime(FIRST)).to.be.eq(expectedStartTime);
      expect(await baseSubscriptionModule.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      expect(await baseSubscriptionModule.hasSubscription(FIRST)).to.be.true;
      expect(await baseSubscriptionModule.hasActiveSubscription(FIRST)).to.be.true;
      expect(await baseSubscriptionModule.hasSubscriptionDebt(FIRST)).to.be.false;
    });

    it("should correctly extend subscription", async () => {
      let duration = 123n;

      const expectedStartTime = BigInt((await time.latest()) + 100);
      let expectedEndTime = expectedStartTime + duration;

      await time.setNextBlockTimestamp(expectedStartTime);
      await baseSubscriptionModule.extendSubscription(FIRST, duration);

      expect(await baseSubscriptionModule.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      const nextTime = expectedEndTime + 100n;
      await time.increaseTo(nextTime);

      expect(await baseSubscriptionModule.hasActiveSubscription(FIRST)).to.be.false;
      expect(await baseSubscriptionModule.hasSubscriptionDebt(FIRST)).to.be.true;

      duration = 3000n;
      const tx = await baseSubscriptionModule.extendSubscription(FIRST, duration);

      expectedEndTime += duration;

      await expect(tx)
        .to.emit(baseSubscriptionModule, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);

      expect(await baseSubscriptionModule.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      expect(await baseSubscriptionModule.hasActiveSubscription(FIRST)).to.be.true;
      expect(await baseSubscriptionModule.hasSubscriptionDebt(FIRST)).to.be.false;
    });
  });
});
