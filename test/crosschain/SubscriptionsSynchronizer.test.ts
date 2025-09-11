import { wei } from "@/scripts";
import { SubscriptionsSynchronizer, WormholeRelayerMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("SubscriptionsSynchronizer", () => {
  const reverter = new Reverter();

  let OWNER: SignerWithAddress;
  let WORMHOLE_RELAYER: SignerWithAddress;
  let SUBSCRIPTION_MANAGER_1: SignerWithAddress;
  let SUBSCRIPTION_MANAGER_2: SignerWithAddress;
  let ACCOUNT_1: SignerWithAddress;
  let ACCOUNT_2: SignerWithAddress;
  let UNAUTHORIZED: SignerWithAddress;

  let wormholeRelayer: WormholeRelayerMock;
  let subscriptionsSynchronizer: SubscriptionsSynchronizer;

  const TARGET_CHAIN_ID = 2;
  const INVALID_CHAIN_ID = 999;
  const TARGET_ADDRESS = "0x1234567890abcdef1234567890abcdef12345678";
  const CROSS_CHAIN_GAS_LIMIT = 500000;
  const SMT_MAX_DEPTH = 32;

  beforeEach(async () => {
    [OWNER, WORMHOLE_RELAYER, SUBSCRIPTION_MANAGER_1, SUBSCRIPTION_MANAGER_2, ACCOUNT_1, ACCOUNT_2, UNAUTHORIZED] =
      await ethers.getSigners();

    wormholeRelayer = await ethers.deployContract("WormholeRelayerMock");

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
      wormholeRelayer: await wormholeRelayer.getAddress(),
      crossChainTxGasLimit: CROSS_CHAIN_GAS_LIMIT,
      SMTMaxDepth: SMT_MAX_DEPTH,
      subscriptionManagers: [SUBSCRIPTION_MANAGER_1.address],
      destinations: [
        {
          chainId: TARGET_CHAIN_ID,
          targetAddress: TARGET_ADDRESS,
        },
      ],
    });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await subscriptionsSynchronizer.getWormholeRelayer()).to.be.deep.eq(await wormholeRelayer.getAddress());
      expect(await subscriptionsSynchronizer.getSubscriptionManagers()).to.be.deep.eq([SUBSCRIPTION_MANAGER_1.address]);
      expect(await subscriptionsSynchronizer.getCrossChainTxGasLimit()).to.be.eq(CROSS_CHAIN_GAS_LIMIT);
      expect(await subscriptionsSynchronizer.isChainSupported(TARGET_CHAIN_ID)).to.be.true;
      expect(await subscriptionsSynchronizer.isChainSupported(INVALID_CHAIN_ID)).to.be.false;
    });

    it("should revert on second initialization", async () => {
      await expect(
        subscriptionsSynchronizer.initialize({
          wormholeRelayer: WORMHOLE_RELAYER.address,
          crossChainTxGasLimit: CROSS_CHAIN_GAS_LIMIT,
          SMTMaxDepth: SMT_MAX_DEPTH,
          subscriptionManagers: [SUBSCRIPTION_MANAGER_1.address],
          destinations: [],
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "InvalidInitialization");
    });
  });

  describe("#sync", () => {
    it("should successfully sync to supported chain", async () => {
      const tx = subscriptionsSynchronizer.sync(TARGET_CHAIN_ID, {
        value: await subscriptionsSynchronizer.quoteCrossChainCost(TARGET_CHAIN_ID),
      });

      await expect(tx).to.emit(subscriptionsSynchronizer, "SyncInitiated");
    });

    it("should revert if chain is not supported", async () => {
      await expect(
        subscriptionsSynchronizer.sync(INVALID_CHAIN_ID, {
          value: await subscriptionsSynchronizer.quoteCrossChainCost(TARGET_CHAIN_ID),
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "ChainNotSupported");
    });

    it("should revert if insufficient funds provided", async () => {
      await expect(subscriptionsSynchronizer.sync(TARGET_CHAIN_ID, { value: 0 })).to.be.revertedWithCustomError(
        subscriptionsSynchronizer,
        "InsufficientFundsForCrossChainDelivery",
      );
    });

    it("should refund excess payment", async () => {
      const amountToSend = wei(1);
      const estimatedPrice = await subscriptionsSynchronizer.quoteCrossChainCost(TARGET_CHAIN_ID);

      const balanceBefore = await ethers.provider.getBalance(OWNER.address);

      const tx = await subscriptionsSynchronizer.sync(TARGET_CHAIN_ID, { value: amountToSend });
      const receipt = await tx.wait();
      const gasUsed = receipt!.gasUsed * receipt!.gasPrice;

      const balanceAfter = await ethers.provider.getBalance(OWNER.address);

      // Should only spend gas + quoted cost, excess should be refunded
      expect(balanceBefore - balanceAfter).to.be.lessThan(gasUsed + estimatedPrice + ethers.parseEther("0.01"));
    });
  });

  describe("#saveSubscriptionData", () => {
    const START_TIME = 1000n;
    const END_TIME = 2000n;

    it("should save new subscription data from authorized manager", async () => {
      const initialRoot = "0x" + "0".repeat(64);
      expect(await subscriptionsSynchronizer.getSubscriptionsSMTRoot()).to.be.equal(initialRoot);

      await subscriptionsSynchronizer
        .connect(SUBSCRIPTION_MANAGER_1)
        .saveSubscriptionData(ACCOUNT_1.address, START_TIME, END_TIME, true);

      // Verify SMT was updated (root should change from initial)
      expect(await subscriptionsSynchronizer.getSubscriptionsSMTRoot()).to.not.equal(initialRoot);
    });

    it("should update existing subscription data from authorized manager", async () => {
      // First, save new subscription
      await subscriptionsSynchronizer
        .connect(SUBSCRIPTION_MANAGER_1)
        .saveSubscriptionData(ACCOUNT_1.address, START_TIME, END_TIME, true);

      const rootAfterAdd = await subscriptionsSynchronizer.getSubscriptionsSMTRoot();

      // Then update it
      const NEW_END_TIME = 3000n;
      await subscriptionsSynchronizer
        .connect(SUBSCRIPTION_MANAGER_1)
        .saveSubscriptionData(ACCOUNT_1.address, START_TIME, NEW_END_TIME, false);

      const rootAfterUpdate = await subscriptionsSynchronizer.getSubscriptionsSMTRoot();

      // Root should change after update
      expect(rootAfterUpdate).to.not.equal(rootAfterAdd);
    });

    it("should revert if called by unauthorized address", async () => {
      await expect(
        subscriptionsSynchronizer
          .connect(UNAUTHORIZED)
          .saveSubscriptionData(ACCOUNT_1.address, START_TIME, END_TIME, true),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "NotSubscriptionManager");
    });
  });

  describe("#updateWormholeRelayer", () => {
    it("should update wormhole relayer", async () => {
      const newRelayer = UNAUTHORIZED.address;

      await expect(subscriptionsSynchronizer.updateWormholeRelayer(newRelayer))
        .to.emit(subscriptionsSynchronizer, "WormholeRelayerUpdated")
        .withArgs(newRelayer);

      expect(await subscriptionsSynchronizer.getWormholeRelayer()).to.be.eq(newRelayer);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).updateWormholeRelayer(UNAUTHORIZED.address),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });

    it("should revert if zero address", async () => {
      await expect(subscriptionsSynchronizer.updateWormholeRelayer(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        subscriptionsSynchronizer,
        "ZeroAddr",
      );
    });
  });

  describe("#addSubscriptionManager", () => {
    it("should add new subscription manager", async () => {
      expect(await subscriptionsSynchronizer.getSubscriptionManagers()).to.deep.eq([SUBSCRIPTION_MANAGER_1.address]);

      await expect(subscriptionsSynchronizer.addSubscriptionManager(SUBSCRIPTION_MANAGER_2.address))
        .to.emit(subscriptionsSynchronizer, "SubscriptionManagerAdded")
        .withArgs(SUBSCRIPTION_MANAGER_2.address);

      // New manager should be able to save data
      expect(
        await subscriptionsSynchronizer
          .connect(SUBSCRIPTION_MANAGER_2)
          .saveSubscriptionData(ACCOUNT_1.address, 1000n, 2000n, true),
      ).to.be.ok;

      expect(await subscriptionsSynchronizer.getSubscriptionManagers()).to.deep.eq([
        SUBSCRIPTION_MANAGER_1.address,
        SUBSCRIPTION_MANAGER_2.address,
      ]);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).addSubscriptionManager(SUBSCRIPTION_MANAGER_2.address),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });

    it("should revert if zero address", async () => {
      await expect(subscriptionsSynchronizer.addSubscriptionManager(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        subscriptionsSynchronizer,
        "ZeroAddr",
      );
    });
  });

  describe("#removeSubscriptionManager", () => {
    beforeEach(async () => {
      // Add second manager for removal tests
      await subscriptionsSynchronizer.addSubscriptionManager(SUBSCRIPTION_MANAGER_2.address);
    });

    it("should remove subscription manager", async () => {
      expect(await subscriptionsSynchronizer.getSubscriptionManagers()).to.be.deep.eq([
        SUBSCRIPTION_MANAGER_1.address,
        SUBSCRIPTION_MANAGER_2.address,
      ]);

      await expect(subscriptionsSynchronizer.removeSubscriptionManager(SUBSCRIPTION_MANAGER_2.address))
        .to.emit(subscriptionsSynchronizer, "SubscriptionManagerRemoved")
        .withArgs(SUBSCRIPTION_MANAGER_2.address);

      // Removed manager should no longer be able to save data
      await expect(
        subscriptionsSynchronizer
          .connect(SUBSCRIPTION_MANAGER_2)
          .saveSubscriptionData(ACCOUNT_1.address, 1000n, 2000n, true),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "NotSubscriptionManager");

      expect(await subscriptionsSynchronizer.getSubscriptionManagers()).to.be.deep.eq([SUBSCRIPTION_MANAGER_1.address]);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).removeSubscriptionManager(SUBSCRIPTION_MANAGER_2.address),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });

    it("should revert if zero address", async () => {
      await expect(
        subscriptionsSynchronizer.removeSubscriptionManager(ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "ZeroAddr");
    });
  });

  describe("#addDestination", () => {
    const NEW_CHAIN_ID = 42;
    const NEW_TARGET_ADDRESS = "0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD";

    it("should add new destination", async () => {
      await expect(
        subscriptionsSynchronizer.addDestination({
          chainId: NEW_CHAIN_ID,
          targetAddress: NEW_TARGET_ADDRESS,
        }),
      )
        .to.emit(subscriptionsSynchronizer, "DestinationAdded")
        .withArgs(NEW_CHAIN_ID, NEW_TARGET_ADDRESS);

      expect(await subscriptionsSynchronizer.isChainSupported(NEW_CHAIN_ID)).to.be.true;
      expect(await subscriptionsSynchronizer.getTargetAddress(NEW_CHAIN_ID)).to.be.eq(NEW_TARGET_ADDRESS);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).addDestination({
          chainId: NEW_CHAIN_ID,
          targetAddress: NEW_TARGET_ADDRESS,
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });

    it("should revert if destination already exists", async () => {
      await expect(
        subscriptionsSynchronizer.addDestination({
          chainId: TARGET_CHAIN_ID, // Already exists
          targetAddress: NEW_TARGET_ADDRESS,
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "DestinationAlreadyExists");
    });

    it("should revert if chain ID is zero", async () => {
      await expect(
        subscriptionsSynchronizer.addDestination({
          chainId: 0,
          targetAddress: NEW_TARGET_ADDRESS,
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "InvalidChainId");
    });

    it("should revert if target address is zero", async () => {
      await expect(
        subscriptionsSynchronizer.addDestination({
          chainId: NEW_CHAIN_ID,
          targetAddress: ethers.ZeroAddress,
        }),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "ZeroAddr");
    });
  });

  describe("#removeDestination", () => {
    it("should remove existing destination", async () => {
      await expect(subscriptionsSynchronizer.removeDestination(TARGET_CHAIN_ID))
        .to.emit(subscriptionsSynchronizer, "DestinationRemoved")
        .withArgs(TARGET_CHAIN_ID);

      expect(await subscriptionsSynchronizer.isChainSupported(TARGET_CHAIN_ID)).to.be.false;
      expect(await subscriptionsSynchronizer.getTargetAddress(TARGET_CHAIN_ID)).to.be.eq(ZeroAddress);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).removeDestination(TARGET_CHAIN_ID),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });

    it("should revert if chain not supported", async () => {
      await expect(subscriptionsSynchronizer.removeDestination(INVALID_CHAIN_ID)).to.be.revertedWithCustomError(
        subscriptionsSynchronizer,
        "ChainNotSupported",
      );
    });
  });

  describe("#setCrossChainTxGasLimit", () => {
    const NEW_GAS_LIMIT = 1000000;

    it("should set new gas limit", async () => {
      await expect(subscriptionsSynchronizer.setCrossChainTxGasLimit(NEW_GAS_LIMIT))
        .to.emit(subscriptionsSynchronizer, "CrossChainTxGasLimitUpdated")
        .withArgs(NEW_GAS_LIMIT);

      expect(await subscriptionsSynchronizer.getCrossChainTxGasLimit()).to.be.eq(NEW_GAS_LIMIT);
    });

    it("should revert if called by non-owner", async () => {
      await expect(
        subscriptionsSynchronizer.connect(UNAUTHORIZED).setCrossChainTxGasLimit(NEW_GAS_LIMIT),
      ).to.be.revertedWithCustomError(subscriptionsSynchronizer, "OwnableUnauthorizedAccount");
    });
  });
});
