import { getRecoverAccountSignature } from "@/test/helpers/sign-utils";
import { AccountSubscriptionManager, ERC20Mock, RecoveryManager, SignatureRecoveryStrategy } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("RecoveryManager", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;

  const paymentTokenSubscriptionCost = wei(5);
  const nativeSubscriptionCost = wei(1, 15);

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;

  let recoveryManager: RecoveryManager;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  function encodeAddress(address: string): string {
    return ethers.AbiCoder.defaultAbiCoder().encode(["address"], [address]);
  }

  before(async () => {
    [OWNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    recoveryManager = await ethers.deployContract("RecoveryManager");

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(address,uint64,address,(address,uint256)[],(address,uint64)[])",
      [
        await recoveryManager.getAddress(),
        basePeriodDuration,
        OWNER.address,
        [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
          },
        ],
        [],
      ],
    );

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      subscriptionManagerInitData,
    ]);
    subscriptionManager = await ethers.getContractAt(
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await recoveryManager.owner()).to.be.eq(OWNER);
      expect(await recoveryManager.subscriptionManagerExists(subscriptionManager)).to.be.true;
      expect(await recoveryManager.getStrategyStatus(0)).to.be.eq(1);
      expect(await recoveryManager.getStrategy(0)).to.be.eq(recoveryStrategy);
      expect(await recoveryManager.isActiveStrategy(0)).to.be.true;
    });

    it("should get exception if try to call init function twice", async () => {
      await expect(recoveryManager.initialize([], [])).to.be.revertedWithCustomError(
        recoveryManager,
        "InvalidInitialization",
      );
    });
  });

  describe("#updateSubscriptionManagers", () => {
    it("should add and remove subscription managers correctly", async () => {
      let tx = await recoveryManager.connect(OWNER).updateSubscriptionManagers([FIRST, SECOND, MASTER_KEY1], true);

      await expect(tx).to.emit(recoveryManager, "SubscriptionManagerAdded").withArgs(FIRST.address);
      await expect(tx).to.emit(recoveryManager, "SubscriptionManagerAdded").withArgs(SECOND.address);
      await expect(tx).to.emit(recoveryManager, "SubscriptionManagerAdded").withArgs(MASTER_KEY1.address);

      expect(await recoveryManager.subscriptionManagerExists(subscriptionManager)).to.be.true;
      expect(await recoveryManager.subscriptionManagerExists(FIRST)).to.be.true;
      expect(await recoveryManager.subscriptionManagerExists(SECOND)).to.be.true;
      expect(await recoveryManager.subscriptionManagerExists(MASTER_KEY1)).to.be.true;
      expect(await recoveryManager.subscriptionManagerExists(OWNER)).to.be.false;

      tx = await recoveryManager.connect(OWNER).updateSubscriptionManagers([MASTER_KEY1, subscriptionManager], false);

      await expect(tx).to.emit(recoveryManager, "SubscriptionManagerRemoved").withArgs(MASTER_KEY1.address);
      await expect(tx)
        .to.emit(recoveryManager, "SubscriptionManagerRemoved")
        .withArgs(await subscriptionManager.getAddress());

      expect(await recoveryManager.subscriptionManagerExists(subscriptionManager)).to.be.false;
      expect(await recoveryManager.subscriptionManagerExists(MASTER_KEY1)).to.be.false;
      expect(await recoveryManager.subscriptionManagerExists(FIRST)).to.be.true;
      expect(await recoveryManager.subscriptionManagerExists(SECOND)).to.be.true;
    });

    it("should not allow to update subscription managers if the caller is not the owner", async () => {
      await expect(recoveryManager.connect(FIRST).updateSubscriptionManagers([FIRST], true))
        .to.be.revertedWithCustomError(recoveryManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#addRecoveryStrategies", () => {
    it("should add recovery strategies correctly", async () => {
      const newRecoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

      await newRecoveryStrategy.initialize(recoveryManager);

      const tx = await recoveryManager.connect(OWNER).addRecoveryStrategies([newRecoveryStrategy]);

      await expect(tx).to.emit(recoveryManager, "StrategyAdded").withArgs(1);

      expect(await recoveryManager.getStrategyStatus(1)).to.be.eq(1);
      expect(await recoveryManager.getStrategy(1)).to.be.eq(newRecoveryStrategy);
      expect(await recoveryManager.isActiveStrategy(1)).to.be.true;
    });

    it("should get exception if try to add zero address as recovery strategy", async () => {
      await expect(recoveryManager.connect(OWNER).addRecoveryStrategies([ZeroAddress])).to.be.revertedWithCustomError(
        recoveryManager,
        "ZeroStrategyAddress",
      );
    });

    it("should get exception if try to set invalid recovery strategy", async () => {
      const newRecoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

      await newRecoveryStrategy.initialize(FIRST);

      await expect(recoveryManager.connect(OWNER).addRecoveryStrategies([newRecoveryStrategy]))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidRecoveryStrategy")
        .withArgs(await newRecoveryStrategy.getAddress());
    });

    it("should not allow to add recovery strategy if the caller is not the owner", async () => {
      await expect(recoveryManager.connect(FIRST).addRecoveryStrategies([FIRST]))
        .to.be.revertedWithCustomError(recoveryManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#enableStrategy", () => {
    it("should enable recovery strategy correctly", async () => {
      await recoveryManager.connect(OWNER).disableStrategy(0);

      const tx = await recoveryManager.connect(OWNER).enableStrategy(0);

      await expect(tx).to.emit(recoveryManager, "StrategyEnabled").withArgs(0);

      expect(await recoveryManager.getStrategyStatus(0)).to.be.eq(1);
      expect(await recoveryManager.getStrategy(0)).to.be.eq(recoveryStrategy);
      expect(await recoveryManager.isActiveStrategy(0)).to.be.true;
    });

    it("should get exception if try to enable recovery strategy with incorrect status", async () => {
      await expect(recoveryManager.connect(OWNER).enableStrategy(1))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(2, 0);

      await expect(recoveryManager.connect(OWNER).enableStrategy(0))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(2, 1);
    });

    it("should not allow to enable recovery strategy if the caller is not the owner", async () => {
      await expect(recoveryManager.connect(FIRST).enableStrategy(0))
        .to.be.revertedWithCustomError(recoveryManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#disableStrategy", () => {
    it("should disable recovery strategy correctly", async () => {
      const tx = await recoveryManager.connect(OWNER).disableStrategy(0);

      await expect(tx).to.emit(recoveryManager, "StrategyDisabled").withArgs(0);

      expect(await recoveryManager.getStrategyStatus(0)).to.be.eq(2);
      expect(await recoveryManager.isActiveStrategy(0)).to.be.false;
    });

    it("should get exception if try to disable recovery strategy with incorrect status", async () => {
      await expect(recoveryManager.connect(OWNER).disableStrategy(1))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(1, 0);

      await recoveryManager.connect(OWNER).disableStrategy(0);

      await expect(recoveryManager.connect(OWNER).disableStrategy(0))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(1, 2);
    });

    it("should not allow to disable recovery strategy if the caller is not the owner", async () => {
      await expect(recoveryManager.connect(FIRST).disableStrategy(0))
        .to.be.revertedWithCustomError(recoveryManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#subscribe", () => {
    it("should subscribe correctly", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      const tx = await recoveryManager.connect(FIRST).subscribe(subscribeData);

      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(FIRST.address);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [FIRST, subscriptionManager],
        [-paymentTokenSubscriptionCost, paymentTokenSubscriptionCost],
      );

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(FIRST)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(FIRST)).to.be.deep.eq([[0n, accountRecoveryData]]);
    });

    it("should subscribe with native token correctly", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ETHER_ADDR, basePeriodDuration, [[0n, accountRecoveryData]]]],
      );

      const tx = await recoveryManager.connect(OWNER).subscribe(subscribeData, {
        value: nativeSubscriptionCost,
      });

      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(OWNER.address);
      await expect(tx).to.changeEtherBalances(
        [OWNER, subscriptionManager],
        [-nativeSubscriptionCost, nativeSubscriptionCost],
      );

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(OWNER)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(OWNER)).to.be.deep.eq([[0n, accountRecoveryData]]);
    });

    it("should subscribe with existing subscription correctly", async () => {
      await paymentToken.connect(SECOND).approve(subscriptionManager, paymentTokenSubscriptionCost);

      await subscriptionManager.connect(SECOND).buySubscription(SECOND, paymentToken, basePeriodDuration);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ZeroAddress, 0n, [[0n, accountRecoveryData]]]],
      );

      const tx = await recoveryManager.connect(SECOND).subscribe(subscribeData);

      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(SECOND.address);
      await expect(tx).to.changeTokenBalances(paymentToken, [SECOND, subscriptionManager], [0, 0]);

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(SECOND)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(SECOND)).to.be.deep.eq([[0n, accountRecoveryData]]);
    });

    it("should subscribe without buying subscription correctly", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ZeroAddress, basePeriodDuration, [[0n, accountRecoveryData]]]],
      );

      const tx = await recoveryManager.connect(SECOND).subscribe(subscribeData);

      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(SECOND.address);

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(SECOND)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(SECOND)).to.be.deep.eq([[0n, accountRecoveryData]]);
    });

    it("should get exception if try to subscribe more than once", async () => {
      await paymentToken.mint(OWNER, paymentTokenSubscriptionCost);
      await paymentToken.connect(OWNER).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [FIRST.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(OWNER).subscribe(subscribeData);

      await expect(recoveryManager.connect(OWNER).subscribe(subscribeData))
        .to.be.revertedWithCustomError(recoveryManager, "AccountAlreadySubscribed")
        .withArgs(OWNER.address);
    });

    it("should get exception if try to subscribe with non-existing subscription manager", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await paymentToken.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData))
        .to.be.revertedWithCustomError(recoveryManager, "SubscriptionManagerDoesNotExist")
        .withArgs(await paymentToken.getAddress());
    });

    it("should get exception if try to subscribe with invalid recovery method", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[1n, accountRecoveryData]],
          ],
        ],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(1, 0);

      const invalidAccountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [ZeroAddress]);

      subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, invalidAccountRecoveryData]],
          ],
        ],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData)).to.be.revertedWithCustomError(
        recoveryStrategy,
        "InvalidAccountRecoveryData",
      );
    });

    it("should get exception if try to subscribe without recovery methods", async () => {
      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ETHER_ADDR, basePeriodDuration, []]],
      );

      await expect(recoveryManager.connect(OWNER).subscribe(subscribeData)).to.be.revertedWithCustomError(
        recoveryManager,
        "NoRecoveryMethodsProvided",
      );
    });
  });

  describe("#unsubscribe", () => {
    it("should unsubscribe correctly", async () => {
      await paymentToken.connect(SECOND).approve(recoveryManager, paymentTokenSubscriptionCost * 2n);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration * 2n,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(SECOND).subscribe(subscribeData);

      const tx = await recoveryManager.connect(SECOND).unsubscribe();

      await expect(tx).to.emit(recoveryManager, "AccountUnsubscribed").withArgs(SECOND.address);

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["tuple(uint256,bytes)[]"], [[]]);

      expect(await recoveryManager.getRecoveryData(SECOND)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(SECOND)).to.be.deep.eq([]);
    });

    it("should get exception when try to unsubscribe before subscribing", async () => {
      await expect(recoveryManager.connect(SECOND).unsubscribe())
        .to.be.revertedWithCustomError(recoveryManager, "AccountNotSubscribed")
        .withArgs(SECOND.address);
    });
  });

  describe("#resubscribe", () => {
    it("should resubscribe correctly", async () => {
      let accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ZeroAddress, basePeriodDuration, [[0n, accountRecoveryData]]]],
      );

      await recoveryManager.connect(FIRST).subscribe(subscribeData);

      let expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(FIRST)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(FIRST)).to.be.deep.eq([[0n, accountRecoveryData]]);

      accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [[await subscriptionManager.getAddress(), ZeroAddress, basePeriodDuration, [[0n, accountRecoveryData]]]],
      );

      const tx = await recoveryManager.connect(FIRST).resubscribe(subscribeData);

      await expect(tx).to.emit(recoveryManager, "AccountUnsubscribed").withArgs(FIRST.address);
      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(FIRST.address);

      expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(uint256,bytes)[]"],
        [[[0, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(FIRST)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getRecoveryMethods(FIRST)).to.be.deep.eq([[0n, accountRecoveryData]]);
    });
  });

  describe("#recover", () => {
    it("should recover correctly", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost * 3n);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration * 3n,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(FIRST).subscribe(subscribeData);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      const subject = encodeAddress(SECOND.address);

      await recoveryManager.connect(FIRST).recover(subject, recoveryProof);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      await expect(recoveryManager.connect(FIRST).recover(subject, recoveryProof)).to.be.revertedWithCustomError(
        recoveryStrategy,
        "InvalidSignature",
      );
    });

    it("should recover with disabled strategy correctly", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(FIRST).subscribe(subscribeData);

      const signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      const recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      await recoveryManager.connect(OWNER).disableStrategy(0);

      await recoveryManager.connect(FIRST).recover(encodeAddress(SECOND.address), recoveryProof);
    });

    it("should get exception if try to recover without recovery method set", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(FIRST).subscribe(subscribeData);

      await recoveryManager.connect(FIRST).unsubscribe();

      const signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0n, signature],
      );

      const subject = encodeAddress(SECOND.address);

      await expect(recoveryManager.connect(FIRST).recover(subject, recoveryProof))
        .to.be.revertedWithCustomError(recoveryManager, "RecoveryMethodNotSet")
        .withArgs(FIRST.address, 0n);

      recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 1n, signature],
      );

      await expect(recoveryManager.connect(FIRST).recover(subject, recoveryProof))
        .to.be.revertedWithCustomError(recoveryManager, "RecoveryMethodNotSet")
        .withArgs(FIRST.address, 1n);
    });

    it("should get exception if try to recover without active subscription", async () => {
      await paymentToken.connect(SECOND).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      await recoveryManager.connect(SECOND).subscribe(subscribeData);

      await time.increaseTo(BigInt(await time.latest()) + basePeriodDuration);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: SECOND.address,
        newOwner: OWNER.address,
        nonce: 0n,
      });

      const recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes"],
        [await subscriptionManager.getAddress(), 0, signature],
      );

      await expect(recoveryManager.connect(SECOND).recover(encodeAddress(OWNER.address), recoveryProof))
        .to.be.revertedWithCustomError(recoveryManager, "NoActiveSubscription")
        .withArgs(await subscriptionManager.getAddress(), SECOND.address);
    });
  });
});
