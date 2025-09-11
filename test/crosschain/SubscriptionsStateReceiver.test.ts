// import { SubscriptionsStateReceiver } from "@ethers-v6";
// import { Reverter } from "@test-helpers";

// import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

// import { expect } from "chai";
// import { ethers } from "hardhat";

// describe.skip("SubscriptionsStateReceiver", () => {
//   const reverter = new Reverter();

//   let WORMHOLE_RELAYER: SignerWithAddress;
//   let SUBSCRIPTIONS_SYNCHRONIZER: SignerWithAddress;
//   let UNAUTHORIZED: SignerWithAddress;

//   let subscriptionsStateReceiver: SubscriptionsStateReceiver;

//   const SOURCE_CHAIN_ID = 2;
//   const INVALID_CHAIN_ID = 999;
//   const TEST_SMT_ROOT = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

//   beforeEach(async () => {
//     [, WORMHOLE_RELAYER, SUBSCRIPTIONS_SYNCHRONIZER, UNAUTHORIZED] = await ethers.getSigners();

//     subscriptionsStateReceiver = await ethers.deployContract("SubscriptionsStateReceiver");

//     await subscriptionsStateReceiver.initialize({
//       wormholeRelayer: WORMHOLE_RELAYER.address,
//       subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//       sourceChainId: SOURCE_CHAIN_ID,
//     });

//     await reverter.snapshot();
//   });

//   afterEach(reverter.revert);

//   describe("#initialize", () => {
//     it("should set correct initial data", async () => {
//       const newReceiver = await ethers.deployContract("SubscriptionsStateReceiver");

//       await expect(
//         newReceiver.initialize({
//           wormholeRelayer: WORMHOLE_RELAYER.address,
//           subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//           sourceChainId: SOURCE_CHAIN_ID,
//         }),
//       )
//         .to.emit(newReceiver, "WormholeRelayerUpdated")
//         .withArgs(WORMHOLE_RELAYER.address)
//         .to.emit(newReceiver, "SubscriptionsSynchronizerUpdated")
//         .withArgs(SUBSCRIPTIONS_SYNCHRONIZER.address)
//         .to.emit(newReceiver, "SourceChainIdUpdated")
//         .withArgs(SOURCE_CHAIN_ID);

//       expect(await newReceiver.getLatestSyncedSMTRoot()).to.equal("0x" + "0".repeat(64));
//     });

//     it("should revert if wormhole relayer is zero address", async () => {
//       const newReceiver = await ethers.deployContract("SubscriptionsStateReceiver");

//       await expect(
//         newReceiver.initialize({
//           wormholeRelayer: ethers.ZeroAddress,
//           subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//           sourceChainId: SOURCE_CHAIN_ID,
//         }),
//       ).to.be.revertedWith("WormholeRelayer: zero address");
//     });

//     it("should revert if subscriptions synchronizer is zero address", async () => {
//       const newReceiver = await ethers.deployContract("SubscriptionsStateReceiver");

//       await expect(
//         newReceiver.initialize({
//           wormholeRelayer: WORMHOLE_RELAYER.address,
//           subscriptionsSynchronizer: ethers.ZeroAddress,
//           sourceChainId: SOURCE_CHAIN_ID,
//         }),
//       ).to.be.revertedWith("SubscriptionsSynchronizer: zero address");
//     });

//     it("should revert if source chain ID is zero", async () => {
//       const newReceiver = await ethers.deployContract("SubscriptionsStateReceiver");

//       await expect(
//         newReceiver.initialize({
//           wormholeRelayer: WORMHOLE_RELAYER.address,
//           subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//           sourceChainId: 0,
//         }),
//       ).to.be.revertedWithCustomError(newReceiver, "InvalidSourceChainId");
//     });

//     it("should revert if source chain ID equals current chain ID", async () => {
//       const newReceiver = await ethers.deployContract("SubscriptionsStateReceiver");
//       const currentChainId = (await ethers.provider.getNetwork()).chainId;

//       await expect(
//         newReceiver.initialize({
//           wormholeRelayer: WORMHOLE_RELAYER.address,
//           subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//           sourceChainId: Number(currentChainId),
//         }),
//       ).to.be.revertedWithCustomError(newReceiver, "InvalidSourceChainId");
//     });

//     it("should revert on second initialization", async () => {
//       await expect(
//         subscriptionsStateReceiver.initialize({
//           wormholeRelayer: WORMHOLE_RELAYER.address,
//           subscriptionsSynchronizer: SUBSCRIPTIONS_SYNCHRONIZER.address,
//           sourceChainId: SOURCE_CHAIN_ID,
//         }),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidInitialization");
//     });
//   });

//   describe("#updateWormholeRelayer", () => {
//     it("should update wormhole relayer", async () => {
//       const newRelayer = UNAUTHORIZED.address;

//       await expect(subscriptionsStateReceiver.updateWormholeRelayer(newRelayer))
//         .to.emit(subscriptionsStateReceiver, "WormholeRelayerUpdated")
//         .withArgs(newRelayer);
//     });

//     it("should revert if called by non-owner", async () => {
//       await expect(
//         subscriptionsStateReceiver.connect(UNAUTHORIZED).updateWormholeRelayer(UNAUTHORIZED.address),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
//     });

//     it("should revert if zero address", async () => {
//       await expect(subscriptionsStateReceiver.updateWormholeRelayer(ethers.ZeroAddress)).to.be.revertedWith(
//         "WormholeRelayer: zero address",
//       );
//     });
//   });

//   describe("#updateSubscriptionsSynchronizer", () => {
//     it("should update subscriptions synchronizer", async () => {
//       const newSynchronizer = UNAUTHORIZED.address;

//       await expect(subscriptionsStateReceiver.updateSubscriptionsSynchronizer(newSynchronizer))
//         .to.emit(subscriptionsStateReceiver, "SubscriptionsSynchronizerUpdated")
//         .withArgs(newSynchronizer);
//     });

//     it("should revert if called by non-owner", async () => {
//       await expect(
//         subscriptionsStateReceiver.connect(UNAUTHORIZED).updateSubscriptionsSynchronizer(UNAUTHORIZED.address),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
//     });

//     it("should revert if zero address", async () => {
//       await expect(subscriptionsStateReceiver.updateSubscriptionsSynchronizer(ethers.ZeroAddress)).to.be.revertedWith(
//         "SubscriptionsSynchronizer: zero address",
//       );
//     });
//   });

//   describe("#updateSourceChainId", () => {
//     it("should update source chain ID", async () => {
//       const newChainId = 42;

//       await expect(subscriptionsStateReceiver.updateSourceChainId(newChainId))
//         .to.emit(subscriptionsStateReceiver, "SourceChainIdUpdated")
//         .withArgs(newChainId);
//     });

//     it("should revert if called by non-owner", async () => {
//       await expect(
//         subscriptionsStateReceiver.connect(UNAUTHORIZED).updateSourceChainId(42),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OwnableUnauthorizedAccount");
//     });

//     it("should revert if chain ID is zero", async () => {
//       await expect(subscriptionsStateReceiver.updateSourceChainId(0)).to.be.revertedWithCustomError(
//         subscriptionsStateReceiver,
//         "InvalidSourceChainId",
//       );
//     });

//     it("should revert if chain ID equals current chain ID", async () => {
//       const currentChainId = (await ethers.provider.getNetwork()).chainId;

//       await expect(
//         subscriptionsStateReceiver.updateSourceChainId(Number(currentChainId)),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidSourceChainId");
//     });
//   });

//   describe("#receiveWormholeMessages", () => {
//     const createValidPayload = (syncTimestamp: number, smtRoot: string) => {
//       return ethers.AbiCoder.defaultAbiCoder().encode(
//         ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
//         [[syncTimestamp, smtRoot]],
//       );
//     };

//     const sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

//     it("should successfully receive and process valid message", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = createValidPayload(syncTimestamp, TEST_SMT_ROOT);

//       await expect(
//         subscriptionsStateReceiver
//           .connect(WORMHOLE_RELAYER)
//           .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
//       )
//         .to.emit(subscriptionsStateReceiver, "MessageReceived")
//         .withArgs(payload);

//       expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
//       expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
//     });

//     it("should revert if called by non-wormhole relayer", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = createValidPayload(syncTimestamp, TEST_SMT_ROOT);

//       await expect(
//         subscriptionsStateReceiver
//           .connect(UNAUTHORIZED)
//           .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "NotWormholeRelayer");
//     });

//     it("should revert if source chain ID is invalid", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = createValidPayload(syncTimestamp, TEST_SMT_ROOT);

//       await expect(
//         subscriptionsStateReceiver
//           .connect(WORMHOLE_RELAYER)
//           .receiveWormholeMessages(payload, [], sourceAddress, INVALID_CHAIN_ID, ethers.ZeroHash),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidSourceChainId");
//     });

//     it("should revert if source address is invalid", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = createValidPayload(syncTimestamp, TEST_SMT_ROOT);
//       const invalidSourceAddress = ethers.zeroPadValue(UNAUTHORIZED.address, 32);

//       await expect(
//         subscriptionsStateReceiver
//           .connect(WORMHOLE_RELAYER)
//           .receiveWormholeMessages(payload, [], invalidSourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "InvalidSourceAddress");
//     });

//     it("should revert if message is outdated", async () => {
//       const firstTimestamp = Math.floor(Date.now() / 1000);
//       const secondTimestamp = firstTimestamp - 100; // Earlier timestamp

//       // Send first message
//       const firstPayload = createValidPayload(firstTimestamp, TEST_SMT_ROOT);
//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(firstPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       // Try to send outdated message with same root
//       const secondPayload = createValidPayload(secondTimestamp, TEST_SMT_ROOT);
//       await expect(
//         subscriptionsStateReceiver
//           .connect(WORMHOLE_RELAYER)
//           .receiveWormholeMessages(secondPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
//       ).to.be.revertedWithCustomError(subscriptionsStateReceiver, "OutdatedSyncMessage");
//     });

//     it("should accept newer message with same root", async () => {
//       const firstTimestamp = Math.floor(Date.now() / 1000);
//       const secondTimestamp = firstTimestamp + 100; // Later timestamp

//       // Send first message
//       const firstPayload = createValidPayload(firstTimestamp, TEST_SMT_ROOT);
//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(firstPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       // Send newer message with same root
//       const secondPayload = createValidPayload(secondTimestamp, TEST_SMT_ROOT);
//       await expect(
//         subscriptionsStateReceiver
//           .connect(WORMHOLE_RELAYER)
//           .receiveWormholeMessages(secondPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash),
//       )
//         .to.emit(subscriptionsStateReceiver, "MessageReceived")
//         .withArgs(secondPayload);

//       expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
//       expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
//     });

//     it("should handle multiple different roots", async () => {
//       const firstTimestamp = Math.floor(Date.now() / 1000);
//       const secondTimestamp = firstTimestamp + 100;
//       const secondRoot = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";

//       // Send first message
//       const firstPayload = createValidPayload(firstTimestamp, TEST_SMT_ROOT);
//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(firstPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       // Send second message with different root
//       const secondPayload = createValidPayload(secondTimestamp, secondRoot);
//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(secondPayload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       // Latest root should be the second one
//       expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(secondRoot);

//       // Both roots should be in history
//       expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
//       expect(await subscriptionsStateReceiver.rootInHistory(secondRoot)).to.be.true;
//     });
//   });

//   describe("#getLatestSyncedSMTRoot", () => {
//     it("should return zero hash initially", async () => {
//       expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal("0x" + "0".repeat(64));
//     });

//     it("should return latest synced root after processing message", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = ethers.AbiCoder.defaultAbiCoder().encode(
//         ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
//         [[syncTimestamp, TEST_SMT_ROOT]],
//       );
//       const sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       expect(await subscriptionsStateReceiver.getLatestSyncedSMTRoot()).to.equal(TEST_SMT_ROOT);
//     });
//   });

//   describe("#rootInHistory", () => {
//     it("should return false for non-existent root", async () => {
//       expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.false;
//     });

//     it("should return true for root that was processed", async () => {
//       const syncTimestamp = Math.floor(Date.now() / 1000);
//       const payload = ethers.AbiCoder.defaultAbiCoder().encode(
//         ["tuple(uint256 syncTimestamp, bytes32 subscriptionsSMTRoot)"],
//         [[syncTimestamp, TEST_SMT_ROOT]],
//       );
//       const sourceAddress = ethers.zeroPadValue(SUBSCRIPTIONS_SYNCHRONIZER.address, 32);

//       await subscriptionsStateReceiver
//         .connect(WORMHOLE_RELAYER)
//         .receiveWormholeMessages(payload, [], sourceAddress, SOURCE_CHAIN_ID, ethers.ZeroHash);

//       expect(await subscriptionsStateReceiver.rootInHistory(TEST_SMT_ROOT)).to.be.true;
//     });

//     it("should return false for zero hash even after initialization", async () => {
//       expect(await subscriptionsStateReceiver.rootInHistory("0x" + "0".repeat(64))).to.be.false;
//     });
//   });
// });
