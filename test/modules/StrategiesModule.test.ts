import { wei } from "@/scripts";
import { StrategiesModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

enum StrategyStatus {
  None,
  Active,
  Disabled,
}

describe("StrategiesModule", () => {
  const reverter = new Reverter();

  const strategy1RecoveryCost = wei(10);
  const strategy2RecoveryCost = wei(20);

  let strategy1: SignerWithAddress;
  let strategy2: SignerWithAddress;

  let strategiesModule: StrategiesModuleMock;

  before(async () => {
    [strategy1, strategy2] = await ethers.getSigners();

    strategiesModule = await ethers.deployContract("StrategiesModuleMock");

    expect(await strategiesModule.getNextStrategyId()).to.equal(0);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("addStrategy", () => {
    it("should correctly add strategy", async () => {
      const expectedStrategyId = await strategiesModule.getNextStrategyId();
      const tx = await strategiesModule.addStrategy(strategy1.address, strategy1RecoveryCost);

      expect(await strategiesModule.getNextStrategyId()).to.equal(expectedStrategyId + 1n);
      expect(await strategiesModule.getStrategyData(expectedStrategyId)).to.deep.equal([
        strategy1RecoveryCost,
        strategy1.address,
        StrategyStatus.Active,
      ]);
      expect(await strategiesModule.isActiveStrategy(expectedStrategyId)).to.be.true;
      expect(await strategiesModule.getStrategy(expectedStrategyId)).to.be.eq(strategy1.address);
      expect(await strategiesModule.getBaseRecoveryCostInUsd(expectedStrategyId)).to.be.eq(strategy1RecoveryCost);

      await expect(tx).to.emit(strategiesModule, "StrategyAdded").withArgs(expectedStrategyId);
    });

    it("should revert if pass zero strategy address", async () => {
      await expect(
        strategiesModule.addStrategy(ethers.ZeroAddress, strategy1RecoveryCost),
      ).to.be.revertedWithCustomError(strategiesModule, "ZeroStrategyAddress");
    });
  });

  describe("disableStrategy", () => {
    const strategyId = 0n;

    beforeEach("setup", async () => {
      await strategiesModule.addStrategy(strategy1.address, strategy1RecoveryCost);

      expect(await strategiesModule.isActiveStrategy(strategyId)).to.be.true;
    });

    it("should correctly disable strategy", async () => {
      const tx = await strategiesModule.disableStrategy(strategyId);

      expect(await strategiesModule.isActiveStrategy(strategyId)).to.be.false;
      expect(await strategiesModule.getStrategyData(strategyId)).to.deep.equal([
        strategy1RecoveryCost,
        strategy1.address,
        StrategyStatus.Disabled,
      ]);

      await expect(tx).to.emit(strategiesModule, "StrategyDisabled").withArgs(strategyId);
    });

    it("should get exception if try to disable non-active strategy", async () => {
      await strategiesModule.disableStrategy(strategyId);

      await expect(strategiesModule.disableStrategy(strategyId))
        .to.be.revertedWithCustomError(strategiesModule, "InvalidStrategyStatus")
        .withArgs(StrategyStatus.Active, StrategyStatus.Disabled);

      await expect(strategiesModule.disableStrategy(strategyId + 1n))
        .to.be.revertedWithCustomError(strategiesModule, "InvalidStrategyStatus")
        .withArgs(StrategyStatus.Active, StrategyStatus.None);
    });
  });

  describe("enableStrategy", () => {
    const strategyId = 0n;

    beforeEach("setup", async () => {
      await strategiesModule.addStrategy(strategy1.address, strategy1RecoveryCost);
      await strategiesModule.disableStrategy(strategyId);

      expect(await strategiesModule.isActiveStrategy(strategyId)).to.be.false;
    });

    it("should correctly enable strategy", async () => {
      const tx = await strategiesModule.enableStrategy(strategyId);

      expect(await strategiesModule.isActiveStrategy(strategyId)).to.be.true;
      expect(await strategiesModule.getStrategyData(strategyId)).to.deep.equal([
        strategy1RecoveryCost,
        strategy1.address,
        StrategyStatus.Active,
      ]);

      await expect(tx).to.emit(strategiesModule, "StrategyEnabled").withArgs(strategyId);
    });

    it("should get exception if try to enable non-disabled strategy", async () => {
      await strategiesModule.enableStrategy(strategyId);

      await expect(strategiesModule.enableStrategy(strategyId))
        .to.be.revertedWithCustomError(strategiesModule, "InvalidStrategyStatus")
        .withArgs(StrategyStatus.Disabled, StrategyStatus.Active);

      await expect(strategiesModule.enableStrategy(strategyId + 1n))
        .to.be.revertedWithCustomError(strategiesModule, "InvalidStrategyStatus")
        .withArgs(StrategyStatus.Disabled, StrategyStatus.None);
    });
  });

  describe("getRecoveryCostInUsdByPeriods", () => {
    it("should return correct recovery cost in USD by periods", async () => {
      await strategiesModule.addStrategy(strategy1.address, strategy1RecoveryCost);
      await strategiesModule.addStrategy(strategy2.address, strategy2RecoveryCost);

      const firstStrategyId = 0n;
      const secondStrategyId = 1n;
      let periodsCount = 4n;

      expect(await strategiesModule.getRecoveryCostInUsdByPeriods(firstStrategyId, periodsCount)).to.equal(
        strategy1RecoveryCost * periodsCount,
      );
      expect(await strategiesModule.getRecoveryCostInUsdByPeriods(secondStrategyId, periodsCount)).to.equal(
        strategy2RecoveryCost * periodsCount,
      );
    });
  });
});
