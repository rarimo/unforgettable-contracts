import {
  IBaseSubscriptionModule,
  SparseMerkleTree,
} from "@/generated-types/ethers/contracts/interfaces/core/ISideChainSubscriptionManager";
import { SideChainSubscriptionManager, SubscriptionsStateReceiver, SubscriptionsSynchronizer } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";
import { get } from "http";

describe("SideChainSubscriptionManager", () => {
  const reverter = new Reverter();

  let OWNER: SignerWithAddress;
  let USER: SignerWithAddress;
  let UNAUTHORIZED: SignerWithAddress;
  let DEPLOYER: SignerWithAddress;

  let sideChainSubscriptionManagerImpl: SideChainSubscriptionManager;
  let sideChainSubscriptionManager: SideChainSubscriptionManager;
  let subscriptionsStateReceiver: SubscriptionsStateReceiver;
  let subscriptionsSynchronizer: SubscriptionsSynchronizer;

  async function deployFreshManager(): Promise<SideChainSubscriptionManager> {
    const freshReceiver = await ethers.deployContract("SubscriptionsStateReceiver");
    const freshReceiverProxy = await ethers.deployContract("ERC1967Proxy", [await freshReceiver.getAddress(), "0x"]);

    const freshReceiverInstance = await ethers.getContractAt(
      "SubscriptionsStateReceiver",
      await freshReceiverProxy.getAddress(),
    );

    await freshReceiverInstance.initialize({
      wormholeRelayer: OWNER.address,
      subscriptionsSynchronizer: OWNER.address,
      sourceChainId: 1,
    });

    const freshImpl = await ethers.deployContract("SideChainSubscriptionManager", [], DEPLOYER);
    const freshProxy = await ethers.deployContract("ERC1967Proxy", [await freshImpl.getAddress(), "0x"]);

    const freshManager = await ethers.getContractAt("SideChainSubscriptionManager", await freshProxy.getAddress());

    await freshManager.connect(DEPLOYER).initialize({
      baseSideChainSubscriptionManagerInitData: {
        subscriptionsStateReceiver: await freshReceiverInstance.getAddress(),
        sourceSubscriptionManager: OWNER.address,
      },
    });

    return freshManager;
  }

  async function getProof(): Promise<SparseMerkleTree.ProofStructOutput> {
    var proof = await subscriptionsSynchronizer.getSubscriptionsSMTProof(OWNER.address, USER.address);
    return {
      root: proof.root,
      key: proof.key,
      value: proof.value,
      siblings: [...proof.siblings],
      existence: proof.existence,
      auxExistence: proof.auxExistence,
      auxKey: proof.auxKey,
      auxValue: proof.auxValue,
    } as SparseMerkleTree.ProofStructOutput;
  }

  beforeEach(async () => {
    [DEPLOYER, OWNER, USER, UNAUTHORIZED] = await ethers.getSigners();

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
      wormholeRelayer: OWNER.address,
      crossChainTxGasLimit: 500000,
      SMTMaxDepth: 80,
      subscriptionManagers: [OWNER.address],
      destinations: [
        {
          chainId: 1,
          targetAddress: ethers.Wallet.createRandom().address,
        },
      ],
    });

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
      wormholeRelayer: OWNER.address,
      subscriptionsSynchronizer: await subscriptionsSynchronizer.getAddress(),
      sourceChainId: 1,
    });

    // Deploy SideChainSubscriptionManager
    sideChainSubscriptionManagerImpl = await ethers.deployContract("SideChainSubscriptionManager", [], DEPLOYER);
    const sideChainSubscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await sideChainSubscriptionManagerImpl.getAddress(),
      "0x",
    ]);

    sideChainSubscriptionManager = await ethers.getContractAt(
      "SideChainSubscriptionManager",
      await sideChainSubscriptionManagerProxy.getAddress(),
    );

    await sideChainSubscriptionManager.initialize({
      baseSideChainSubscriptionManagerInitData: {
        subscriptionsStateReceiver: await subscriptionsStateReceiver.getAddress(),
        sourceSubscriptionManager: OWNER.address,
      },
    });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("Deployment and Initialization", () => {
    it("should deploy and initialize correctly", async () => {
      expect(await sideChainSubscriptionManager.getSourceSubscriptionManager()).to.equal(OWNER.address);
      expect(await sideChainSubscriptionManager.getSubscriptionsStateReceiver()).to.equal(
        await subscriptionsStateReceiver.getAddress(),
      );
    });

    it("should not allow initialization twice", async () => {
      await expect(
        sideChainSubscriptionManager.connect(DEPLOYER).initialize({
          baseSideChainSubscriptionManagerInitData: {
            subscriptionsStateReceiver: await subscriptionsStateReceiver.getAddress(),
            sourceSubscriptionManager: OWNER.address,
          },
        }),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "InvalidInitialization");
    });

    it("should not allow non-deployer to initialize", async () => {
      const newImpl = await ethers.deployContract("SideChainSubscriptionManager", [], DEPLOYER);
      const newProxy = await ethers.deployContract("ERC1967Proxy", [await newImpl.getAddress(), "0x"]);

      const newManager = await ethers.getContractAt("SideChainSubscriptionManager", await newProxy.getAddress());

      await expect(
        newManager.connect(OWNER).initialize({
          baseSideChainSubscriptionManagerInitData: {
            subscriptionsStateReceiver: await subscriptionsStateReceiver.getAddress(),
            sourceSubscriptionManager: OWNER.address,
          },
        }),
      ).to.be.revertedWithCustomError(newManager, "OnlyDeployer");
    });
  });

  describe("Access Control", () => {
    it("should allow owner to pause", async () => {
      await expect(sideChainSubscriptionManager.pause()).to.emit(sideChainSubscriptionManager, "Paused");

      expect(await sideChainSubscriptionManager.paused()).to.be.true;
    });

    it("should allow owner to unpause", async () => {
      await sideChainSubscriptionManager.pause();

      await expect(sideChainSubscriptionManager.unpause()).to.emit(sideChainSubscriptionManager, "Unpaused");

      expect(await sideChainSubscriptionManager.paused()).to.be.false;
    });

    it("should not allow non-owner to pause", async () => {
      await expect(sideChainSubscriptionManager.connect(UNAUTHORIZED).pause()).to.be.revertedWithCustomError(
        sideChainSubscriptionManager,
        "OwnableUnauthorizedAccount",
      );
    });

    it("should not allow non-owner to unpause", async () => {
      await sideChainSubscriptionManager.pause();

      await expect(sideChainSubscriptionManager.connect(UNAUTHORIZED).unpause()).to.be.revertedWithCustomError(
        sideChainSubscriptionManager,
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("Configuration Management", () => {
    it("should allow owner to set subscriptions state receiver", async () => {
      const newReceiver = ethers.Wallet.createRandom().address;

      await expect(sideChainSubscriptionManager.setSubscriptionsStateReceiver(newReceiver))
        .to.emit(sideChainSubscriptionManager, "SubscriptionsStateReceiverUpdated")
        .withArgs(newReceiver);
    });

    it("should not allow setting zero address as subscriptions state receiver", async () => {
      await expect(
        sideChainSubscriptionManager.setSubscriptionsStateReceiver(ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "ZeroAddr");
    });

    it("should allow owner to set source subscription manager", async () => {
      const newSourceManager = ethers.Wallet.createRandom().address;

      await expect(sideChainSubscriptionManager.setSourceSubscriptionManager(newSourceManager))
        .to.emit(sideChainSubscriptionManager, "SourceSubscriptionManagerUpdated")
        .withArgs(newSourceManager);
    });

    it("should not allow setting zero address as source subscription manager", async () => {
      await expect(
        sideChainSubscriptionManager.setSourceSubscriptionManager(ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "ZeroAddr");
    });

    it("should not allow non-owner to set subscriptions state receiver", async () => {
      const newReceiver = ethers.Wallet.createRandom().address;

      await expect(
        sideChainSubscriptionManager.connect(UNAUTHORIZED).setSubscriptionsStateReceiver(newReceiver),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "OwnableUnauthorizedAccount");
    });

    it("should not allow non-owner to set source subscription manager", async () => {
      const newSourceManager = ethers.Wallet.createRandom().address;

      await expect(
        sideChainSubscriptionManager.connect(UNAUTHORIZED).setSourceSubscriptionManager(newSourceManager),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "OwnableUnauthorizedAccount");
    });
  });

  describe("Subscription Synchronization", () => {
    let startTime: number;
    let endTime: number;
    let subscriptionData: IBaseSubscriptionModule.AccountSubscriptionDataStruct;

    beforeEach(async () => {
      startTime = await time.latest();
      endTime = startTime + 86400;

      subscriptionData = {
        startTime: startTime,
        endTime: startTime + 86400,
      };
      await subscriptionsSynchronizer.connect(OWNER).saveSubscriptionData(USER.address, startTime, endTime, true);

      // Add the root to state receiver history via receiveWormholeMessages
      const payload = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
        [[startTime, await subscriptionsSynchronizer.getSubscriptionsSMTRoot()]],
      );

      const sourceAddress = ethers.zeroPadValue(await subscriptionsSynchronizer.getAddress(), 32);

      // Acting as wormhole relayer
      await subscriptionsStateReceiver
        .connect(OWNER)
        .receiveWormholeMessages(payload, [], sourceAddress, 1, ethers.ZeroHash);
    });

    it("should sync subscription with valid proof", async () => {
      await expect(
        sideChainSubscriptionManager.connect(USER).syncSubscription(USER.address, subscriptionData, await getProof()),
      )
        .to.emit(sideChainSubscriptionManager, "SubscriptionSynced")
        .withArgs(USER.address, startTime, endTime);

      expect(await sideChainSubscriptionManager.hasSubscription(USER.address)).to.be.true;
      expect(await sideChainSubscriptionManager.getSubscriptionStartTime(USER.address)).to.equal(startTime);
      expect(await sideChainSubscriptionManager.getSubscriptionEndTime(USER.address)).to.equal(endTime);
    });

    it("should not sync subscription when paused", async () => {
      await sideChainSubscriptionManager.pause();

      await expect(
        sideChainSubscriptionManager.connect(USER).syncSubscription(USER.address, subscriptionData, await getProof()),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "EnforcedPause");
    });

    it("should revert with invalid proof key", async () => {
      var proof = await getProof();
      proof.key = ethers.keccak256(ethers.toUtf8Bytes("invalid"));

      await expect(
        sideChainSubscriptionManager.connect(USER).syncSubscription(USER.address, subscriptionData, proof),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "InvalidProofKey");
    });

    it("should revert with invalid proof value", async () => {
      var proof = await getProof();
      proof.value = ethers.keccak256(ethers.toUtf8Bytes("invalid"));

      await expect(
        sideChainSubscriptionManager.connect(USER).syncSubscription(USER.address, subscriptionData, proof),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "InvalidProofValue");
    });

    it("should revert with unknown root", async () => {
      // Don't add the root to state receiver, should fail verification
      const newManager = await deployFreshManager();

      var proof = await subscriptionsSynchronizer.getSubscriptionsSMTProof(OWNER.address, USER.address);

      await expect(
        newManager.connect(USER).syncSubscription(USER.address, subscriptionData, await getProof()),
      ).to.be.revertedWithCustomError(newManager, "UnknownRoot");
    });

    it("should only set start time on first sync", async () => {
      // First sync
      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, subscriptionData, await getProof());

      const firstStartTime = await sideChainSubscriptionManager.getSubscriptionStartTime(USER.address);

      // Second sync with different start time
      const newStartTime = firstStartTime + 1000n;
      const newSubscriptionData = { ...subscriptionData, startTime: newStartTime };

      await subscriptionsSynchronizer.connect(OWNER).saveSubscriptionData(USER.address, newStartTime, endTime, false);

      await subscriptionsStateReceiver
        .connect(OWNER)
        .receiveWormholeMessages(
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
            [[newStartTime, await subscriptionsSynchronizer.getSubscriptionsSMTRoot()]],
          ),
          [],
          ethers.zeroPadValue(await subscriptionsSynchronizer.getAddress(), 32),
          1,
          ethers.ZeroHash,
        );

      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, newSubscriptionData, await getProof());

      // Start time should remain the same
      expect(await sideChainSubscriptionManager.getSubscriptionStartTime(USER.address)).to.equal(firstStartTime);
    });

    it("should only extend end time if new end time is greater", async () => {
      // First sync
      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, subscriptionData, await getProof());

      const firstEndTime = await sideChainSubscriptionManager.getSubscriptionEndTime(USER.address);

      // Second sync with earlier end time - should not update
      const earlierEndTime = endTime - 1000;
      const earlierSubscriptionData = { ...subscriptionData, endTime: earlierEndTime };

      await subscriptionsSynchronizer
        .connect(OWNER)
        .saveSubscriptionData(USER.address, startTime, earlierEndTime, false);

      await subscriptionsStateReceiver
        .connect(OWNER)
        .receiveWormholeMessages(
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
            [[earlierEndTime, await subscriptionsSynchronizer.getSubscriptionsSMTRoot()]],
          ),
          [],
          ethers.zeroPadValue(await subscriptionsSynchronizer.getAddress(), 32),
          1,
          ethers.ZeroHash,
        );

      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, earlierSubscriptionData, await getProof());
      expect(await sideChainSubscriptionManager.getSubscriptionEndTime(USER.address)).to.equal(firstEndTime);

      // Third sync with later end time - should update
      const laterEndTime = endTime + 1000;
      const laterSubscriptionData = { ...subscriptionData, endTime: laterEndTime };

      await subscriptionsSynchronizer.connect(OWNER).saveSubscriptionData(USER.address, startTime, laterEndTime, false);

      await subscriptionsStateReceiver
        .connect(OWNER)
        .receiveWormholeMessages(
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
            [[laterEndTime, await subscriptionsSynchronizer.getSubscriptionsSMTRoot()]],
          ),
          [],
          ethers.zeroPadValue(await subscriptionsSynchronizer.getAddress(), 32),
          1,
          ethers.ZeroHash,
        );

      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, laterSubscriptionData, await getProof());
      expect(await sideChainSubscriptionManager.getSubscriptionEndTime(USER.address)).to.equal(laterEndTime);
    });
  });

  describe("Subscription Status Queries", () => {
    beforeEach(async () => {
      const currentTime = await time.latest();

      const subscriptionData = { startTime: currentTime, endTime: currentTime + 86400 };

      await subscriptionsSynchronizer
        .connect(OWNER)
        .saveSubscriptionData(USER.address, subscriptionData.startTime, subscriptionData.endTime, true);

      // Add the root to state receiver history via receiveWormholeMessages
      const payload = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
        [[currentTime, await subscriptionsSynchronizer.getSubscriptionsSMTRoot()]],
      );

      const sourceAddress = ethers.zeroPadValue(await subscriptionsSynchronizer.getAddress(), 32);

      await subscriptionsStateReceiver
        .connect(OWNER) // Acting as wormhole relayer
        .receiveWormholeMessages(payload, [], sourceAddress, 1, ethers.ZeroHash);

      await sideChainSubscriptionManager
        .connect(USER)
        .syncSubscription(USER.address, subscriptionData, await getProof());
    });

    it("should return correct subscription status", async () => {
      expect(await sideChainSubscriptionManager.hasSubscription(USER.address)).to.be.true;
      expect(await sideChainSubscriptionManager.hasActiveSubscription(USER.address)).to.be.true;
      expect(await sideChainSubscriptionManager.hasSubscriptionDebt(USER.address)).to.be.false;
    });

    it("should detect subscription debt when expired", async () => {
      // Fast forward time beyond subscription end
      await time.increaseTo((await time.latest()) + 86400 + 1);

      expect(await sideChainSubscriptionManager.hasSubscription(USER.address)).to.be.true;
      expect(await sideChainSubscriptionManager.hasActiveSubscription(USER.address)).to.be.false;
      expect(await sideChainSubscriptionManager.hasSubscriptionDebt(USER.address)).to.be.true;
    });

    it("should return correct times for non-subscribed user", async () => {
      const currentTime = await time.latest();

      expect(await sideChainSubscriptionManager.hasSubscription(UNAUTHORIZED.address)).to.be.false;
      expect(await sideChainSubscriptionManager.hasActiveSubscription(UNAUTHORIZED.address)).to.be.false;
      expect(await sideChainSubscriptionManager.hasSubscriptionDebt(UNAUTHORIZED.address)).to.be.false;
      expect(await sideChainSubscriptionManager.getSubscriptionStartTime(UNAUTHORIZED.address)).to.equal(0);
      expect(await sideChainSubscriptionManager.getSubscriptionEndTime(UNAUTHORIZED.address)).to.be.closeTo(
        currentTime,
        5,
      );
    });
  });

  describe("Upgradeability", () => {
    it("should return correct implementation address", async () => {
      const implAddress = await sideChainSubscriptionManager.implementation();
      expect(implAddress).to.equal(await sideChainSubscriptionManagerImpl.getAddress());
    });

    it("should allow owner to upgrade", async () => {
      const newImpl = await ethers.deployContract("SideChainSubscriptionManager", [], DEPLOYER);

      await expect(sideChainSubscriptionManager.upgradeToAndCall(await newImpl.getAddress(), "0x")).to.not.be.reverted;
    });

    it("should not allow non-owner to upgrade", async () => {
      const newImpl = await ethers.deployContract("SideChainSubscriptionManager", [], DEPLOYER);

      await expect(
        sideChainSubscriptionManager.connect(UNAUTHORIZED).upgradeToAndCall(await newImpl.getAddress(), "0x"),
      ).to.be.revertedWithCustomError(sideChainSubscriptionManager, "OwnableUnauthorizedAccount");
    });
  });
});
