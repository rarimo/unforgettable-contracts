import { SBTMock, SBTPaymentModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("SBTPaymentModule", () => {
  const reverter = new Reverter();

  const subscriptionDurationPerToken = 3600n * 24n * 30n;

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;

  let sbt: SBTMock;
  let sbtPaymentModule: SBTPaymentModuleMock;

  beforeEach(async () => {
    [OWNER, FIRST] = await ethers.getSigners();

    sbt = await ethers.deployContract("SBTMock");
    sbtPaymentModule = await ethers.deployContract("SBTPaymentModuleMock");

    await sbt.initialize("TestSBT", "TSBT", [OWNER, sbtPaymentModule]);

    await sbtPaymentModule.initialize({
      sbtEntries: [
        {
          sbt: sbt,
          subscriptionDurationPerToken: subscriptionDurationPerToken,
        },
      ],
    });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await sbtPaymentModule.isSupportedSBT(sbt)).to.be.true;
      expect(await sbtPaymentModule.getSubscriptionDurationPerSBT(sbt)).to.be.eq(subscriptionDurationPerToken);
      expect(await sbtPaymentModule.getSupportedSBTs()).to.be.deep.eq([await sbt.getAddress()]);
    });

    it("should get exception if try to call init function directly", async () => {
      await expect(sbtPaymentModule.__SBTPaymentModule_init({ sbtEntries: [] })).to.be.revertedWithCustomError(
        sbtPaymentModule,
        "NotInitializing",
      );
    });
  });

  describe("#updateSBT", () => {
    it("should correctly add sbt and set subscription duration", async () => {
      const newSBT = await ethers.deployContract("SBTMock");
      const newSubscriptionDurationPerToken = subscriptionDurationPerToken * 12n;

      const tx = await sbtPaymentModule.updateSBT(newSBT, newSubscriptionDurationPerToken);

      await expect(tx)
        .to.emit(sbtPaymentModule, "SBTAdded")
        .withArgs(await newSBT.getAddress());
      await expect(tx)
        .to.emit(sbtPaymentModule, "SubscriptionDurationPerSBTUpdated")
        .withArgs(await newSBT.getAddress(), newSubscriptionDurationPerToken);

      expect(await sbtPaymentModule.isSupportedSBT(newSBT)).to.be.true;
      expect(await sbtPaymentModule.getSubscriptionDurationPerSBT(newSBT)).to.be.eq(newSubscriptionDurationPerToken);
    });

    it("should correctly update existing sbt subscription time", async () => {
      const newSubscriptionDurationPerToken = subscriptionDurationPerToken * 12n;

      const tx = await sbtPaymentModule.updateSBT(sbt, newSubscriptionDurationPerToken);

      await expect(tx).to.not.emit(sbtPaymentModule, "SBTAdded");
      await expect(tx)
        .to.emit(sbtPaymentModule, "SubscriptionDurationPerSBTUpdated")
        .withArgs(await sbt.getAddress(), newSubscriptionDurationPerToken);

      expect(await sbtPaymentModule.getSubscriptionDurationPerSBT(sbt)).to.be.eq(newSubscriptionDurationPerToken);
    });
  });

  describe("#addSBT", () => {
    it("should correctly add sbt contract", async () => {
      const newSBT = await ethers.deployContract("SBTMock");

      const tx = await sbtPaymentModule.addSBT(newSBT);

      await expect(tx)
        .to.emit(sbtPaymentModule, "SBTAdded")
        .withArgs(await newSBT.getAddress());

      expect(await sbtPaymentModule.isSupportedSBT(newSBT)).to.be.true;
      expect(await sbtPaymentModule.getSupportedSBTs()).to.be.deep.eq([
        await sbt.getAddress(),
        await newSBT.getAddress(),
      ]);
    });

    it("should get exception if try to add existing sbt", async () => {
      await expect(sbtPaymentModule.addSBT(sbt))
        .to.revertedWithCustomError(sbtPaymentModule, "SBTAlreadyAdded")
        .withArgs(await sbt.getAddress());
    });

    it("should get exception if try to add zero address", async () => {
      await expect(sbtPaymentModule.addSBT(ethers.ZeroAddress))
        .to.revertedWithCustomError(sbtPaymentModule, "ZeroAddr")
        .withArgs("SBT");
    });
  });

  describe("#removeSBT", () => {
    it("should correctly remove SBT", async () => {
      const tx = await sbtPaymentModule.removeSBT(sbt);

      await expect(tx)
        .to.emit(sbtPaymentModule, "SBTRemoved")
        .withArgs(await sbt.getAddress());

      expect(await sbtPaymentModule.isSupportedSBT(sbt)).to.be.false;
      expect(await sbtPaymentModule.getSupportedSBTs()).to.be.deep.eq([]);
      expect(await sbtPaymentModule.getSubscriptionDurationPerSBT(sbt)).to.be.eq(0n);
    });

    it("should get exception if try to remove unsupported SBT", async () => {
      const newSBT = await ethers.deployContract("SBTMock");

      expect(await sbtPaymentModule.isSupportedSBT(newSBT)).to.be.false;

      await expect(sbtPaymentModule.removeSBT(newSBT))
        .to.revertedWithCustomError(sbtPaymentModule, "NotSupportedSBT")
        .withArgs(await newSBT.getAddress());
    });
  });

  describe("#buySubscriptionWithSBT", () => {
    it("should correctly buy subscription with SBT", async () => {
      const tokenId = 123;
      await sbt.mint(OWNER, tokenId);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + subscriptionDurationPerToken;

      await time.setNextBlockTimestamp(startTime);
      const tx = await sbtPaymentModule.buySubscriptionWithSBT(FIRST, sbt, tokenId);

      expect(await sbt.balanceOf(OWNER)).to.be.eq(0n);
      await expect(sbt.ownerOf(tokenId)).to.be.reverted;

      await expect(tx)
        .to.emit(sbtPaymentModule, "SubscriptionExtended")
        .withArgs(FIRST.address, subscriptionDurationPerToken, expectedEndTime);
      await expect(tx)
        .to.emit(sbtPaymentModule, "SubscriptionBoughtWithSBT")
        .withArgs(await sbt.getAddress(), OWNER.address, tokenId);

      expect(await sbtPaymentModule.getSubscriptionStartTime(FIRST)).to.be.eq(startTime);
      expect(await sbtPaymentModule.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      expect(await sbtPaymentModule.hasSubscription(FIRST)).to.be.true;
      expect(await sbtPaymentModule.hasActiveSubscription(FIRST)).to.be.true;
    });

    it("should get exception if the sender is not an token owner", async () => {
      const tokenId = 123;
      await sbt.mint(OWNER, tokenId);

      await expect(sbtPaymentModule.connect(FIRST).buySubscriptionWithSBT(FIRST, sbt, tokenId))
        .to.be.revertedWithCustomError(sbtPaymentModule, "NotASBTOwner")
        .withArgs(await sbt.getAddress(), FIRST.address, tokenId);
    });

    it("should get exception if the SBT token not supported", async () => {
      await expect(sbtPaymentModule.connect(FIRST).buySubscriptionWithSBT(FIRST, FIRST, 1n))
        .to.revertedWithCustomError(sbtPaymentModule, "NotSupportedSBT")
        .withArgs(FIRST.address);
    });
  });
});
