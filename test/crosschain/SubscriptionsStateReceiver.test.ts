import { SubscriptionsStateReceiver } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("SubscriptionsStateReceiver", () => {
  const reverter = new Reverter();

  let WORMHOLE_RELAYER: SignerWithAddress;
  let SUBSCRIPTIONS_SYNCHRONIZER: SignerWithAddress;
  let UNAUTHORIZED: SignerWithAddress;

  let sourceAddress: string;
  let subscriptionsStateReceiver: SubscriptionsStateReceiver;

  const SOURCE_CHAIN_ID = 3;
  const INVALID_CHAIN_ID = 999;
  const TEST_SMT_ROOT = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

  beforeEach(async () => {
    [, WORMHOLE_RELAYER, SUBSCRIPTIONS_SYNCHRONIZER, UNAUTHORIZED] = await ethers.getSigners();

    sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

    const subscriptionsStateReceiverImpl = await ethers.deployContract("SubscriptionsStateReceiver");
    const subscriptionsStateReceiverProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionsStateReceiverImpl.getAddress(),
      "0x",
    ]);

    subscriptionsStateReceiver = await ethers.getContractAt(
      "SubscriptionsStateReceiver",
      await subscriptionsStateReceiverProxy.getAddress(),
    );

    await subscriptionsStateReceiver.initialize({
      wormholeRelayer: WORMHOLE_RELAYER.address,
      subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
      sourceChainId: SOURCE_CHAIN_ID,
    });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.eq("0x" + "0".repeat(64));
      expect(await subscriptionsStateReceiver.getWormholeRelayer()).to.eq(WORMHOLE_RELAYER.address);
      expect(await subscriptionsStateReceiver.getSourceSubscriptionsSynchronizer()).to.eq(
        SUBSCRIPTIONS_SYNCHRONIZER.address,
      );
      expect(await subscriptionsStateReceiver.getSourceChainId()).to.eq(SOURCE_CHAIN_ID);
    });

    it("should revert on second initialization", async () => {
      await expect(
        subscriptionsStateReceiver.initialize({
          wormholeRelayer: WORMHOLE_RELAYER.address,
          subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
          sourceChainId: SOURCE_CHAIN_ID,
        }),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidInitialization");
    });
  });

  describe("#updateWormholeRelayer", () => {
    it("should update wormhole relayer", async () => {
      const newRelayer = UNAUTHORIZED.address;

      await expect(subscriptionsStateReceiver.updateWormholeRelayer(newRelayer))
        .to.emit(subscriptionsStateReceiver, "WormholeRelayerUpdated")
        .withArgs(newRelayer);

      expect(await subscriptionsStateReceiver.getWormholeRelayer()).to.eq(newRelayer);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsStateReceiver.connect(UNAUTHORIZED).updateWormholeRelayer(UNAUTHORIZED.address),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
    });

    it("should revert if zero address", async () => {
      await expect(subscriptionsStateReceiver.updateWormholeRelayer(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        subscriptionsStateReceiver,
        "ZeroAddr",
      );
    });
  });

  describe("#updateSubscriptionsSynchronizer", () => {
    it("should update subscriptions synchronizer", async () => {
      const newSynchronizer = UNAUTHORIZED.address;

      await expect(subscriptionsStateReceiver.updateSubscriptionsSynchronizer(newSynchronizer))
        .to.emit(subscriptionsStateReceiver, "SubscriptionsSynchronizerUpdated")
        .withArgs(newSynchronizer);

      expect(await subscriptionsStateReceiver.getSourceSubscriptionsSynchronizer()).to.eq(newSynchronizer);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsStateReceiver.connect(UNAUTHORIZED).updateSubscriptionsSynchronizer(UNAUTHORIZED.address),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
    });

    it("should revert if zero address", async () => {
      await expect(
        subscriptionsStateReceiver.updateSubscriptionsSynchronizer(ethers.ZeroAddress),
      ).revertedWithCustomError(subscriptionsStateReceiver, "ZeroAddr");
    });
  });

  describe("#updateSourceChainId", () => {
    it("should update source chain ID", async () => {
      const newChainId = 42;

      await expect(subscriptionsStateReceiver.updateSourceChainId(newChainId))
        .to.emit(subscriptionsStateReceiver, "SourceChainIdUpdated")
        .withArgs(newChainId);

      expect(await subscriptionsStateReceiver.getSourceChainId()).to.eq(newChainId);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsStateReceiver.connect(UNAUTHORIZED).updateSourceChainId(42),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
    });

    it("should revert if chain ID is zero", async () => {
      await expect(subscriptionsStateReceiver.updateSourceChainId(0)).to.be.revertedWithCustomError(
        subscriptionsStateReceiver,
        "InvalidSourceChainId",
      );
    });

    it("should revert if chain ID equals current chain ID", async () => {
      const currentChainId = (await ethers.provider.getNetwork()).chainId;

      await expect(subscriptionsStateReceiver.updateSourceChainId(currentChainId)).to.be.revertedWithCustomError(
        subscriptionsStateReceiver,
        "InvalidSourceChainId",
      );
    });
  });

  describe("#receiveWormholeMessages", () => {
    const createValidPayload = (syncTimestamp: number, smtRoot: string) => {
      return ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
        [[syncTimestamp, smtRoot]],
      );
    };

    it("should successfully receive and process valid message", async () => {
      const payload = createValidPayload(await time.latest(), TEST_SMT_ROOT);

      await expect(
        subscriptionsStateReceiver
          .connect(WORMHOLE_RELAYER)
          .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
      )
        .to.emit(subscriptionsStateReceiver, "MessageReceived")
        .withArgs(payload);

      expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
      expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
    });

    it("should revert if called by non-wormhole relayer", async () => {
      const payload = createValidPayload(await time.latest(), TEST_SMT_ROOT);

      await expect(
        subscriptionsStateReceiver
          .connect(UNAUTHORIZED)
          .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "NotWormholeRelayer");
    });

    it("should revert if source chain ID is invalid", async () => {
      const payload = createValidPayload(await time.latest(), TEST_SMT_ROOT);

      await expect(
        subscriptionsStateReceiver
          .connect(WORMHOLE_RELAYER)
          .receiveWormholeMessages(payload, [], sourceAddress, INVALID_CHAIN_ID, ethers.ZeroHash),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidSourceChainId");
    });

    it("should revert if source address is invalid", async () => {
      const payload = createValidPayload(await time.latest(), TEST_SMT_ROOT);

      const invalidSourceAddress = ethers.zeroPadValue(UNAUTHORIZED.address, 32);
      await expect(
        subscriptionsStateReceiver
          .connect(WORMHOLE_RELAYER)
          .receiveWormholeMessages(payload, [], invalidSourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidSourceAddress");
    });

    it("should revert if message is outdated", async () => {
      const firstTimestamp = await time.latest();
      const secondTimestamp = firstTimestamp - 1; // Earlier timestamp

      // Send first message
      await subscriptionsStateReceiver
        .connect(WORMHOLE_RELAYER)
        .receiveWormholeMessages(
          createValidPayload(firstTimestamp, TEST_SMT_ROOT),
          [],
          sourceAddress,
          SOURCE_CHAIN_ID,
          ethers.ZeroHash,
        );

      // Try to send outdated message with same root
      const secondPayload = createValidPayload(secondTimestamp, TEST_SMT_ROOT);

      await expect(
        subscriptionsStateReceiver
          .connect(WORMHOLE_RELAYER)
          .receiveWormholeMessages(secondPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
      ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OutdatedSyncMessage");
    });

    it("should accept newer message with same root", async () => {
      const firstTimestamp = await time.latest();
      const secondTimestamp = firstTimestamp + 100; // Later timestamp

      // Send first message
      await subscriptionsStateReceiver
        .connect(WORMHOLE_RELAYER)
        .receiveWormholeMessages(
          createValidPayload(firstTimestamp, TEST_SMT_ROOT),
          [],
          sourceAddress,
          SOURCE_CHAIN_ID,
          ethers.ZeroHash,
        );

      // Send newer message with same root
      const payload = createValidPayload(secondTimestamp, TEST_SMT_ROOT);
      await expect(
        subscriptionsStateReceiver
          .connect(WORMHOLE_RELAYER)
          .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
      )
        .to.emit(subscriptionsStateReceiver, "MessageReceived")
        .withArgs(payload);

      expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
      expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
    });
  });

  describe("#getLatestSyncedSMTRoot", () => {
    it("should return zero hash initially", async () => {
      expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal("0x" + "0".repeat(64));
    });

    it("should return latest synced root after processing message", async () => {
      const syncTimestamp = await time.latest();
      const payload = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
        [[syncTimestamp, TEST_SMT_ROOT]],
      );

      const sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

      await subscriptionsStateReceiver
        .connect(WORMHOLE_RELAYER)
        .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

      expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
    });
  });

  describe("#rootInHistory", () => {
    it("should return false for non-existent root", async () => {
      expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.false;
    });

    it("should return true for root that was processed", async () => {
      const syncTimestamp = await time.latest();
      const payload = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
        [[syncTimestamp, TEST_SMT_ROOT]],
      );

      const sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

      await subscriptionsStateReceiver
        .connect(WORMHOLE_RELAYER)
        .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

      expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
    });

    it("should return false for zero hash even after initialization", async () => {
      expect(await subscriptionsStateReceiver.rootInHistory("0x" + "0".repeat(64))).to.be.false;
    });
  });
});
