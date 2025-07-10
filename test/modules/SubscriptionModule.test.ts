import { ISubscriptionModule } from "@/generated-types/ethers/contracts/modules/SubscriptionModule";
import { PERCENTAGE_100, PRECISION } from "@/scripts";
import { SubscriptionModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("SubscriptionModule", () => {
  const reverter = new Reverter();

  const basePeriodDuration = 30 * 24 * 60 * 60; // 30 days in seconds
  const defaultRecoverySecurityPercentage = PERCENTAGE_100;

  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;

  let subscriptionModule: SubscriptionModuleMock;

  before(async () => {
    [FIRST, SECOND] = await ethers.getSigners();

    subscriptionModule = await ethers.deployContract("SubscriptionModuleMock");

    await subscriptionModule.setBasePeriodDuration(basePeriodDuration);

    expect(await subscriptionModule.getBasePeriodDuration()).to.be.equal(basePeriodDuration);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("setBasePeriodDuration", () => {
    it("should correctly set base period duration", async () => {
      const newSubscriptionModule = await ethers.deployContract("SubscriptionModuleMock");
      const tx = await newSubscriptionModule.setBasePeriodDuration(basePeriodDuration);

      expect(await newSubscriptionModule.getBasePeriodDuration()).to.equal(basePeriodDuration);
      await expect(tx).to.emit(newSubscriptionModule, "BasePeriodDurationUpdated").withArgs(basePeriodDuration);
    });

    it("should revert if base period duration is zero or less than the previous", async () => {
      const newSubscriptionModule = await ethers.deployContract("SubscriptionModuleMock");
      await expect(newSubscriptionModule.setBasePeriodDuration(0))
        .to.be.revertedWithCustomError(newSubscriptionModule, "InvalidBasePeriodDuration")
        .withArgs(0);

      await newSubscriptionModule.setBasePeriodDuration(basePeriodDuration);

      await expect(newSubscriptionModule.setBasePeriodDuration(basePeriodDuration))
        .to.be.revertedWithCustomError(newSubscriptionModule, "InvalidBasePeriodDuration")
        .withArgs(basePeriodDuration);
    });
  });

  describe("updateSubscriptionPeriod", () => {
    it("should correctly update subscription period", async () => {
      const newDuration = basePeriodDuration * 6; // 6 months in seconds
      const costFactor = PRECISION * 112n; // 112%

      const tx = await subscriptionModule.updateSubscriptionPeriod(newDuration, costFactor);

      expect(await subscriptionModule.subscriptionPeriodExists(newDuration)).to.be.true;
      expect(await subscriptionModule.getSubscriptionPeriodFactor(newDuration)).to.equal(costFactor);

      await expect(tx).to.emit(subscriptionModule, "SubscriptionPeriodUpdated").withArgs(newDuration, costFactor);
    });

    it("should get exception if pass invalid duration", async () => {
      const newDuration = basePeriodDuration * 6 - 100; // 6 months in seconds
      const costFactor = PRECISION * 112n; // 112%

      await expect(subscriptionModule.updateSubscriptionPeriod(newDuration, costFactor))
        .to.be.revertedWithCustomError(subscriptionModule, "InvalidSubscriptionDuration")
        .withArgs(newDuration);
    });
  });

  describe("removeSubscriptionPeriod", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);
    });

    it("should correctly remove subscription period", async () => {
      const tx = await subscriptionModule.removeSubscriptionPeriod(oneYearDuration);

      expect(await subscriptionModule.subscriptionPeriodExists(oneYearDuration)).to.be.false;
      expect(await subscriptionModule.getSubscriptionPeriodFactor(oneYearDuration)).to.equal(0);

      await expect(tx).to.emit(subscriptionModule, "SubscriptionPeriodRemoved").withArgs(oneYearDuration);
    });

    it("should get exception if pass invalid duration", async () => {
      const invalidDuration = basePeriodDuration * 6; // 6 months in seconds

      await expect(subscriptionModule.removeSubscriptionPeriod(invalidDuration))
        .to.be.revertedWithCustomError(subscriptionModule, "SubscriptionPeriodDoesNotExist")
        .withArgs(invalidDuration);
    });
  });

  describe("createNewSubscription", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };
    });

    it("should correctly create new subscription", async () => {
      const expectedSubscriptionId = 1n;
      const startTime = (await time.latest()) + 100;

      expect(await subscriptionModule.getCurrentAccountSubscriptionId(FIRST.address)).to.equal(0n);

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );

      const info = await subscriptionModule.getSubscriptionInfo(expectedSubscriptionId);
      expect(info.subscriptionId).to.equal(expectedSubscriptionId);
      expect(info.account).to.equal(FIRST.address);
      expect(info.recoverySecurityPercentage).to.equal(defaultRecoverySecurityPercentage);
      expect(info.startTime).to.equal(startTime);
      expect(info.endTime).to.equal(startTime + oneYearDuration);
      expect(info.activeRecoveryMethods[0]).to.deep.equal([
        testRecoveryMethod.strategyId,
        testRecoveryMethod.recoveryData,
      ]);
      expect(await subscriptionModule.getSubscriptionAccount(expectedSubscriptionId)).to.equal(FIRST.address);

      await expect(tx)
        .to.emit(subscriptionModule, "SubscriptionCreated")
        .withArgs(FIRST.address, expectedSubscriptionId, oneYearDuration);
    });

    it("should correctly create several subscriptions for the one user", async () => {
      let expectedSubscriptionId = 1n;
      let startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      let tx = await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );

      await expect(tx)
        .to.emit(subscriptionModule, "SubscriptionCreated")
        .withArgs(FIRST.address, expectedSubscriptionId, oneYearDuration);

      const secondSubscriptionStartTime = startTime + oneYearDuration;
      expectedSubscriptionId += 1n;

      tx = await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );

      const info = await subscriptionModule.getSubscriptionInfo(expectedSubscriptionId);
      expect(info.subscriptionId).to.equal(expectedSubscriptionId);
      expect(info.account).to.equal(FIRST.address);
      expect(info.recoverySecurityPercentage).to.equal(defaultRecoverySecurityPercentage);
      expect(info.startTime).to.equal(secondSubscriptionStartTime);
      expect(info.endTime).to.equal(secondSubscriptionStartTime + oneYearDuration);
      expect(info.activeRecoveryMethods[0]).to.deep.equal([
        testRecoveryMethod.strategyId,
        testRecoveryMethod.recoveryData,
      ]);

      expect(await subscriptionModule.getCurrentAccountSubscriptionId(FIRST.address)).to.equal(
        expectedSubscriptionId - 1n,
      );
    });

    it("should get exception if pass zero address as subscriber", async () => {
      await expect(
        subscriptionModule.createNewSubscription(
          ethers.ZeroAddress,
          oneYearDuration,
          defaultRecoverySecurityPercentage,
          [testRecoveryMethod],
        ),
      ).to.be.revertedWithCustomError(subscriptionModule, "ZeroAccountAddress");
    });

    it("should get exception if pass zero recovery methods", async () => {
      await expect(
        subscriptionModule.createNewSubscription(FIRST, oneYearDuration, defaultRecoverySecurityPercentage, []),
      ).to.be.revertedWithCustomError(subscriptionModule, "EmptyRecoveryMethodsArr");
    });
  });

  describe("extendSubscription", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    const subscriptionId = 1n;
    let startTime: number;
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };

      startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );
    });

    it("should correctly extend subscription", async () => {
      expect(await subscriptionModule.getAccountSubscriptionsEndTime(FIRST)).to.be.eq(startTime + oneYearDuration);

      const tx = await subscriptionModule.extendSubscription(subscriptionId, oneYearDuration);

      const expectedNewEndTime = startTime + oneYearDuration * 2;

      expect(await subscriptionModule.getAccountSubscriptionsEndTime(FIRST)).to.be.eq(expectedNewEndTime);

      await expect(tx).to.emit(subscriptionModule, "SubscriptionExtended").withArgs(subscriptionId, oneYearDuration);
    });

    it("should get exception if subscription does not exist", async () => {
      const invalidSubscriptionId = 100n;

      await expect(subscriptionModule.extendSubscription(invalidSubscriptionId, oneYearDuration))
        .to.be.revertedWithCustomError(subscriptionModule, "SubscriptionDoesNotExist")
        .withArgs(invalidSubscriptionId);
    });

    it("should get exception if try to extend not last subscription", async () => {
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );

      await expect(subscriptionModule.extendSubscription(subscriptionId, oneYearDuration))
        .to.be.revertedWithCustomError(subscriptionModule, "UnableToExtendSubscription")
        .withArgs(subscriptionId);
    });

    it("should get exception if pass invalid duration", async () => {
      const invalidDuration = basePeriodDuration * 6;

      await expect(subscriptionModule.extendSubscription(subscriptionId, invalidDuration))
        .to.be.revertedWithCustomError(subscriptionModule, "SubscriptionPeriodDoesNotExist")
        .withArgs(invalidDuration);
    });
  });

  describe("changeRecoverySecurityPercentage", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    const subscriptionId = 1n;
    let startTime: number;
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };

      startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );
    });

    it("should correctly change recovery security percentage", async () => {
      const newRecoverySecurityPercentage = PERCENTAGE_100 / 2n;

      const tx = await subscriptionModule.changeRecoverySecurityPercentage(
        subscriptionId,
        newRecoverySecurityPercentage,
      );

      expect(await subscriptionModule.getSubscriptionRecoverySecurityPercentage(subscriptionId)).to.equal(
        newRecoverySecurityPercentage,
      );

      await expect(tx)
        .to.emit(subscriptionModule, "RecoverySecurityPercentageChanged")
        .withArgs(subscriptionId, newRecoverySecurityPercentage);
    });

    it("should get exception if pass invalid percentage", async () => {
      const invalidPercentage = PERCENTAGE_100 + 1n;

      await expect(subscriptionModule.changeRecoverySecurityPercentage(subscriptionId, invalidPercentage))
        .to.be.revertedWithCustomError(subscriptionModule, "InvalidRecoverySecurityPercentage")
        .withArgs(invalidPercentage);
      await expect(subscriptionModule.changeRecoverySecurityPercentage(subscriptionId, 0n))
        .to.be.revertedWithCustomError(subscriptionModule, "InvalidRecoverySecurityPercentage")
        .withArgs(0n);
    });
  });

  describe("changeRecoveryData", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    const subscriptionId = 1n;
    let startTime: number;
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };

      startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );
    });

    it("should correctly change recovery data", async () => {
      const methodId = 0n;
      const newRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      const tx = await subscriptionModule.changeRecoveryData(subscriptionId, methodId, newRecoveryData);

      const info = await subscriptionModule.getSubscriptionInfo(subscriptionId);
      expect(info.activeRecoveryMethods[0].recoveryData).to.equal(newRecoveryData);

      expect(await subscriptionModule.getActiveRecoveryMethod(subscriptionId, methodId)).to.deep.equal([
        testRecoveryMethod.strategyId,
        newRecoveryData,
      ]);

      await expect(tx).to.emit(subscriptionModule, "RecoveryDataChanged").withArgs(subscriptionId, methodId);
    });

    it("should get exception if try to change recovery data for non-active recovery method", async () => {
      const invalidMethodId = 100n;
      const newRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      await expect(subscriptionModule.changeRecoveryData(subscriptionId, invalidMethodId, newRecoveryData))
        .to.be.revertedWithCustomError(subscriptionModule, "NotAnActiveRecoveryMethod")
        .withArgs(subscriptionId, invalidMethodId);
    });
  });

  describe("addRecoveryMethod", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    const subscriptionId = 1n;
    let startTime: number;
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };

      startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod],
      );
    });

    it("should correctly add new recovery method", async () => {
      const newMethodId = 1;
      const newRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct = {
        strategyId: 14n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]),
      };

      const tx = await subscriptionModule.addRecoveryMethod(subscriptionId, newRecoveryMethod);

      const info = await subscriptionModule.getSubscriptionInfo(subscriptionId);
      expect(info.activeRecoveryMethods.length).to.equal(2);
      expect(info.activeRecoveryMethods[newMethodId]).to.deep.equal([
        newRecoveryMethod.strategyId,
        newRecoveryMethod.recoveryData,
      ]);

      expect(await subscriptionModule.getActiveRecoveryMethod(subscriptionId, newMethodId)).to.deep.equal([
        newRecoveryMethod.strategyId,
        newRecoveryMethod.recoveryData,
      ]);

      await expect(tx).to.emit(subscriptionModule, "RecoveryMethodAdded").withArgs(subscriptionId, newMethodId);
    });
  });

  describe("removeRecoveryMethod", () => {
    const oneYearDuration = basePeriodDuration * 12; // 12 months in seconds
    const oneYearCostFactor = PERCENTAGE_100; // 100%
    const subscriptionId = 1n;
    let startTime: number;
    let testRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;
    let secondRecoveryMethod: ISubscriptionModule.RecoveryMethodStruct;

    beforeEach("setup", async () => {
      await subscriptionModule.updateSubscriptionPeriod(oneYearDuration, oneYearCostFactor);

      testRecoveryMethod = {
        strategyId: 13n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]),
      };
      secondRecoveryMethod = {
        strategyId: 14n,
        recoveryData: ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]),
      };

      startTime = (await time.latest()) + 100;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionModule.createNewSubscription(
        FIRST.address,
        oneYearDuration,
        defaultRecoverySecurityPercentage,
        [testRecoveryMethod, secondRecoveryMethod],
      );
    });

    it("should correctly remove recovery method", async () => {
      const methodId = 0n;

      const tx = await subscriptionModule.removeRecoveryMethod(subscriptionId, methodId);

      const info = await subscriptionModule.getSubscriptionInfo(subscriptionId);
      expect(info.activeRecoveryMethods.length).to.equal(1);
      expect(info.activeRecoveryMethods[0]).to.deep.equal([
        secondRecoveryMethod.strategyId,
        secondRecoveryMethod.recoveryData,
      ]);

      await expect(tx).to.emit(subscriptionModule, "RecoveryMethodRemoved").withArgs(subscriptionId, methodId);
    });

    it("should get exception if try to remove last recovery method", async () => {
      let methodId = 0n;
      await subscriptionModule.removeRecoveryMethod(subscriptionId, methodId);

      methodId = 1n;

      await expect(subscriptionModule.removeRecoveryMethod(subscriptionId, methodId)).to.be.revertedWithCustomError(
        subscriptionModule,
        "UnableToRemoveLastRecoveryMethod",
      );
    });

    it("should get exception if try to remove non-active recovery method", async () => {
      const invalidMethodId = 100n;

      await expect(subscriptionModule.removeRecoveryMethod(subscriptionId, invalidMethodId))
        .to.be.revertedWithCustomError(subscriptionModule, "NotAnActiveRecoveryMethod")
        .withArgs(subscriptionId, invalidMethodId);
    });
  });

  describe("getPeriodsCountByTime", () => {
    it("should return correct periods count by time", async () => {
      expect(await subscriptionModule.getPeriodsCountByTime(basePeriodDuration * 2)).to.equal(2);
      expect(await subscriptionModule.getPeriodsCountByTime(basePeriodDuration * 12 + 1000)).to.equal(13);
      expect(await subscriptionModule.getPeriodsCountByTime(basePeriodDuration * 12 - 1000)).to.equal(12);
    });
  });
});
