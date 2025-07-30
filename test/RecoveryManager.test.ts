import { getRecoverAccountSignature } from "@/test/helpers/sign-utils";
import { AccountSubscriptionManager, ERC20Mock, RecoveryManagerMock, SignatureRecoveryStrategy } from "@ethers-v6";
import { wei } from "@scripts";
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

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;

  let recoveryManager: RecoveryManagerMock;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  before(async () => {
    [OWNER, FIRST, SECOND, MASTER_KEY1] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(uint64,address,(address,uint256)[],(address,uint64)[])",
      [
        basePeriodDuration,
        OWNER.address,
        [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
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
    recoveryManager = await ethers.deployContract("RecoveryManagerMock");

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

  describe("#subscribe", () => {
    it("should subscribe correctly", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [0n, accountRecoveryData],
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
        ["tuple(address,tuple(uint256,bytes))"],
        [[await subscriptionManager.getAddress(), [0n, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(FIRST)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getSubscriptionManager(FIRST)).to.be.eq(subscriptionManager);
      expect(await recoveryManager.getRecoveryMethod(FIRST)).to.be.deep.eq([0n, accountRecoveryData]);
    });

    it("should subscribe with existing subscription correctly", async () => {
      await paymentToken.connect(SECOND).approve(subscriptionManager, paymentTokenSubscriptionCost);

      await subscriptionManager.connect(SECOND).buySubscription(SECOND, paymentToken, basePeriodDuration);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [[await subscriptionManager.getAddress(), ZeroAddress, 0n, [0n, accountRecoveryData]]],
      );

      const tx = await recoveryManager.connect(SECOND).subscribe(subscribeData);

      await expect(tx).to.emit(recoveryManager, "AccountSubscribed").withArgs(SECOND.address);
      await expect(tx).to.changeTokenBalances(paymentToken, [SECOND, subscriptionManager], [0, 0]);

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,tuple(uint256,bytes))"],
        [[await subscriptionManager.getAddress(), [0n, accountRecoveryData]]],
      );

      expect(await recoveryManager.getRecoveryData(SECOND)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getSubscriptionManager(SECOND)).to.be.eq(subscriptionManager);
      expect(await recoveryManager.getRecoveryMethod(SECOND)).to.be.deep.eq([0n, accountRecoveryData]);
    });

    it("should get exception if try to subscribe with non-existing subscription manager", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await paymentToken.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [0n, accountRecoveryData],
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
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [1n, accountRecoveryData],
          ],
        ],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData))
        .to.be.revertedWithCustomError(recoveryManager, "InvalidStrategyStatus")
        .withArgs(1, 0);

      const invalidAccountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [ZeroAddress]);

      subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [0n, invalidAccountRecoveryData],
          ],
        ],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData)).to.be.revertedWithCustomError(
        recoveryStrategy,
        "InvalidAccountRecoveryData",
      );
    });

    it("should get exception if try to subscribe without paid subscription", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [SECOND.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [[await subscriptionManager.getAddress(), ZeroAddress, basePeriodDuration, [0n, accountRecoveryData]]],
      );

      await expect(recoveryManager.connect(FIRST).subscribe(subscribeData))
        .to.be.revertedWithCustomError(recoveryManager, "NoActiveSubscription")
        .withArgs(await subscriptionManager.getAddress(), FIRST.address);
    });
  });

  describe("#unsubscribe", () => {
    it("should unsubscribe correctly", async () => {
      await paymentToken.connect(SECOND).approve(recoveryManager, paymentTokenSubscriptionCost * 2n);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [OWNER.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration * 2n,
            [0n, accountRecoveryData],
          ],
        ],
      );

      await recoveryManager.connect(SECOND).subscribe(subscribeData);

      const tx = await recoveryManager.connect(SECOND).unsubscribe();

      await expect(tx).to.emit(recoveryManager, "AccountUnsubscribed").withArgs(SECOND.address);

      const expectedRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,tuple(uint256,bytes))"],
        [[ZeroAddress, [0n, ethers.getBytes("0x")]]],
      );

      expect(await recoveryManager.getRecoveryData(SECOND)).to.be.eq(expectedRecoveryData);
      expect(await recoveryManager.getSubscriptionManager(SECOND)).to.be.eq(ZeroAddress);
      expect(await recoveryManager.getRecoveryMethod(SECOND)).to.be.deep.eq([0n, "0x"]);
    });
  });

  describe("#recover", () => {
    it("should recover correctly", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost * 3n);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration * 3n,
            [0n, accountRecoveryData],
          ],
        ],
      );

      await recoveryManager.connect(FIRST).subscribe(subscribeData);

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      await recoveryManager.connect(FIRST).recover(SECOND.address, signature);

      signature = await getRecoverAccountSignature(recoveryStrategy, OWNER, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      await expect(recoveryManager.connect(FIRST).recover(SECOND.address, signature)).to.be.revertedWithCustomError(
        recoveryStrategy,
        "RecoveryFailed",
      );
    });

    it("should get exception if try to recover without recovery method set", async () => {
      await paymentToken.connect(FIRST).approve(recoveryManager, paymentTokenSubscriptionCost * 3n);

      const signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: FIRST.address,
        newOwner: SECOND.address,
        nonce: 0n,
      });

      await expect(recoveryManager.connect(FIRST).recover(SECOND.address, signature))
        .to.be.revertedWithCustomError(recoveryManager, "RecoveryMethodNotSet")
        .withArgs(FIRST.address);
    });

    it("should get exception if try to recover without active subscription", async () => {
      await paymentToken.connect(SECOND).approve(recoveryManager, paymentTokenSubscriptionCost);

      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes))"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [0n, accountRecoveryData],
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

      await expect(recoveryManager.connect(SECOND).recover(OWNER.address, signature))
        .to.be.revertedWithCustomError(recoveryManager, "NoActiveSubscription")
        .withArgs(await subscriptionManager.getAddress(), SECOND.address);
    });
  });
});
