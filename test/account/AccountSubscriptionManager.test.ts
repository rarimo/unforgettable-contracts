import { AccountSubscriptionManager, ERC20Mock, RecoveryManagerMock, SBTMock } from "@ethers-v6";
import { ETHER_ADDR, wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

import { getBuySubscriptionSignature } from "../helpers/sign-utils";

describe("AccountSubscriptionManager", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;
  const sbtSubscriptionDuration = basePaymentPeriod * 12n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;
  let recoveryManager: RecoveryManagerMock;

  let paymentToken: ERC20Mock;
  let sbt: SBTMock;

  before(async () => {
    [OWNER, FIRST, SECOND, SUBSCRIPTION_SIGNER] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);
    sbt = await ethers.deployContract("SBTMock");

    await sbt.initialize("Mock SBT", "MSBT", [OWNER]);

    recoveryManager = await ethers.deployContract("RecoveryManagerMock");

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);
    subscriptionManager = await ethers.getContractAt(
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    await subscriptionManager.initialize({
      subscriptionCreators: [await recoveryManager.getAddress()],
      tokensPaymentInitData: {
        basePaymentPeriod: basePaymentPeriod,
        durationFactorEntries: [],
        paymentTokenEntries: [
          {
            paymentToken: ETHER_ADDR,
            baseSubscriptionCost: nativeSubscriptionCost,
          },
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
      },
      sbtPaymentInitData: {
        sbtEntries: [
          {
            sbt: await sbt.getAddress(),
            subscriptionDurationPerToken: sbtSubscriptionDuration,
          },
        ],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: SUBSCRIPTION_SIGNER,
      },
    });

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await sbt.addOwners([subscriptionManager]);

    expect(await sbt.isOwner(subscriptionManager)).to.be.true;

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialization", () => {
    it("should correctly set initial data", async () => {
      expect(await subscriptionManager.owner()).to.be.eq(OWNER);
      expect(await subscriptionManager.implementation()).to.be.eq(subscriptionManagerImpl);
      expect(await subscriptionManager.getSubscriptionCreators()).to.be.deep.eq([await recoveryManager.getAddress()]);
      expect(await subscriptionManager.getBasePaymentPeriod()).to.be.eq(basePaymentPeriod);
      expect(await subscriptionManager.getSubscriptionSigner()).to.be.eq(SUBSCRIPTION_SIGNER);

      expect(await subscriptionManager.getPaymentTokens()).to.be.deep.eq([ETHER_ADDR, await paymentToken.getAddress()]);

      expect(await subscriptionManager.isSupportedToken(ETHER_ADDR)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(nativeSubscriptionCost);
      expect(await subscriptionManager.isSupportedToken(paymentToken)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      expect(await subscriptionManager.isSupportedSBT(sbt)).to.be.true;
      expect(await subscriptionManager.getSubscriptionDurationPerSBT(sbt)).to.be.eq(sbtSubscriptionDuration);
    });

    it("should get exception if not a deployer try to call init function", async () => {
      const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
        await subscriptionManagerImpl.getAddress(),
        "0x",
      ]);
      const newSubscriptionManager = await ethers.getContractAt(
        "AccountSubscriptionManager",
        await subscriptionManagerProxy.getAddress(),
      );

      await expect(
        newSubscriptionManager.connect(FIRST).initialize({
          subscriptionCreators: [await recoveryManager.getAddress()],
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
        }),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OnlyDeployer")
        .withArgs(FIRST.address);
    });

    it("should get exception if try to call init function twice", async () => {
      await expect(
        subscriptionManager.initialize({
          subscriptionCreators: [await recoveryManager.getAddress()],
          tokensPaymentInitData: {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
          },
          sbtPaymentInitData: {
            sbtEntries: [],
          },
          sigSubscriptionInitData: {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
        }),
      ).to.be.revertedWithCustomError(subscriptionManager, "InvalidInitialization");
    });

    it("should get exception if try to call BaseSubscriptionManager directly", async () => {
      await expect(
        subscriptionManager.__BaseSubscriptionManager_init(
          [await recoveryManager.getAddress()],
          {
            basePaymentPeriod: basePaymentPeriod,
            durationFactorEntries: [],
            paymentTokenEntries: [],
          },
          {
            sbtEntries: [],
          },
          {
            subscriptionSigner: SUBSCRIPTION_SIGNER,
          },
        ),
      ).to.be.revertedWithCustomError(subscriptionManager, "NotInitializing");
    });
  });

  describe("#upgrade", () => {
    it("should correctly upgrade AccountSubscriptionManager contract", async () => {
      const newSubscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManagerMock");

      const subscriptionManagerMock = await ethers.getContractAt("AccountSubscriptionManagerMock", subscriptionManager);

      await expect(subscriptionManagerMock.version()).to.be.revertedWithoutReason();

      await subscriptionManager.upgradeToAndCall(newSubscriptionManagerImpl, "0x");

      expect(await subscriptionManager.implementation()).to.be.eq(newSubscriptionManagerImpl);

      expect(await subscriptionManagerMock.version()).to.be.eq("v2.2.1");
    });

    it("should get exception if not an owner try to upgrade AccountSubscriptionManager", async () => {
      const newSubscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManagerMock");

      await expect(subscriptionManager.connect(FIRST).upgradeToAndCall(newSubscriptionManagerImpl, "0x"))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#pause", () => {
    it("should correctly pause AccountSubscriptionManager contract", async () => {
      await subscriptionManager.pause();

      expect(await subscriptionManager.paused()).to.be.true;
    });

    it("should get exception if not an owner try to pause AccountSubscriptionManager", async () => {
      await expect(subscriptionManager.connect(FIRST).pause())
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#unpause", () => {
    it("should correctly unpause AccountSubscriptionManager contract", async () => {
      await subscriptionManager.pause();

      expect(await subscriptionManager.paused()).to.be.true;

      await subscriptionManager.unpause();

      expect(await subscriptionManager.paused()).to.be.false;
    });

    it("should get exception if not an owner try to unpause AccountSubscriptionManager", async () => {
      await subscriptionManager.pause();

      await expect(subscriptionManager.connect(FIRST).unpause())
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#setSubscriptionSigner", () => {
    it("should correctly set new subscription signer", async () => {
      const tx = await subscriptionManager.setSubscriptionSigner(FIRST);

      expect(await subscriptionManager.getSubscriptionSigner()).to.be.eq(FIRST);

      await expect(tx).to.emit(subscriptionManager, "SubscriptionSignerUpdated").withArgs(FIRST.address);
    });

    it("should get exception if pass zero address", async () => {
      await expect(subscriptionManager.setSubscriptionSigner(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        subscriptionManager,
        "ZeroAddr",
      );
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).setSubscriptionSigner(FIRST))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updatePaymentTokens", () => {
    it("should correctly add new payment tokens", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);
      const subscriptionCost = wei(5);

      const tx = await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await newToken.getAddress(),
          baseSubscriptionCost: subscriptionCost,
        },
      ]);

      expect(await subscriptionManager.isSupportedToken(await newToken.getAddress())).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(await newToken.getAddress())).to.be.eq(
        subscriptionCost,
      );

      await expect(tx)
        .to.emit(subscriptionManager, "PaymentTokenAdded")
        .withArgs(await newToken.getAddress());
      await expect(tx)
        .to.emit(subscriptionManager, "BaseSubscriptionCostUpdated")
        .withArgs(await newToken.getAddress(), subscriptionCost);
    });

    it("should correctly update subscription cost", async () => {
      const newSubscriptionCost = nativeSubscriptionCost * 2n;
      const tx = await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: newSubscriptionCost,
        },
      ]);

      expect(await subscriptionManager.isSupportedToken(ETHER_ADDR)).to.be.true;
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(newSubscriptionCost);

      await expect(tx)
        .to.emit(subscriptionManager, "BaseSubscriptionCostUpdated")
        .withArgs(ETHER_ADDR, newSubscriptionCost);
    });

    it("should get exception if pass zero address", async () => {
      await expect(
        subscriptionManager.updatePaymentTokens([
          {
            paymentToken: ethers.ZeroAddress,
            baseSubscriptionCost: wei(1),
          },
        ]),
      ).to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr");
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updatePaymentTokens([
          {
            paymentToken: FIRST.address,
            baseSubscriptionCost: wei(1),
          },
        ]),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#removePaymentTokens", () => {
    it("should correctly remove payment tokens", async () => {
      const tx = await subscriptionManager.removePaymentTokens([ETHER_ADDR, await paymentToken.getAddress()]);

      expect(await subscriptionManager.isSupportedToken(ETHER_ADDR)).to.be.false;
      expect(await subscriptionManager.isSupportedToken(paymentToken)).to.be.false;

      await expect(tx).to.emit(subscriptionManager, "PaymentTokenRemoved").withArgs(ETHER_ADDR);
      await expect(tx)
        .to.emit(subscriptionManager, "PaymentTokenRemoved")
        .withArgs(await paymentToken.getAddress());
    });

    it("should get exception if try to remove not supported token", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);

      await expect(subscriptionManager.removePaymentTokens([await newToken.getAddress()]))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotSupported")
        .withArgs(await newToken.getAddress());
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).removePaymentTokens([ETHER_ADDR]))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateDurationFactor", () => {
    it("should correctly update duration factor", async () => {
      const duration = basePaymentPeriod * 2n;
      const durationFactor = 2n;
      const tx = await subscriptionManager.updateDurationFactor(duration, durationFactor);

      expect(await subscriptionManager.getSubscriptionDurationFactor(duration)).to.be.eq(durationFactor);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionDurationFactorUpdated")
        .withArgs(duration, durationFactor);
    });

    it("should get exception if not an owner try to call this function", async () => {
      const duration = basePaymentPeriod * 2n;
      const durationFactor = 2n;

      await expect(subscriptionManager.connect(FIRST).updateDurationFactor(duration, durationFactor))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#withdrawTokens", () => {
    it("should correctly withdraw native tokens", async () => {
      await subscriptionManager.buySubscription(FIRST, ETHER_ADDR, basePaymentPeriod, {
        value: nativeSubscriptionCost,
      });

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;

      const tx = await subscriptionManager.withdrawTokens(ETHER_ADDR, FIRST, ethers.MaxUint256);

      await expect(tx)
        .to.emit(subscriptionManager, "TokensWithdrawn")
        .withArgs(ETHER_ADDR, FIRST, nativeSubscriptionCost);
      await expect(tx).to.changeEtherBalances(
        [subscriptionManager, FIRST],
        [-nativeSubscriptionCost, nativeSubscriptionCost],
      );
    });

    it("should correctly withdraw ERC20 tokens", async () => {
      const amountToWithdraw = wei(1000);

      await paymentToken.mint(subscriptionManager, amountToWithdraw);

      const tx = await subscriptionManager.withdrawTokens(paymentToken, FIRST, ethers.MaxUint256);

      await expect(tx)
        .to.emit(subscriptionManager, "TokensWithdrawn")
        .withArgs(await paymentToken.getAddress(), FIRST, amountToWithdraw);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [subscriptionManager, FIRST],
        [-amountToWithdraw, amountToWithdraw],
      );
    });

    it("should get exception if pass zero recipient address", async () => {
      await expect(
        subscriptionManager.withdrawTokens(ETHER_ADDR, ethers.ZeroAddress, wei(1)),
      ).to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr");
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).withdrawTokens(ETHER_ADDR, FIRST, wei(1)))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#updateSBTs", () => {
    it("should correctly update sbt tokens settings", async () => {
      const newSbt = await ethers.deployContract("SBTMock");
      const subscriptionDurationPerToken = basePaymentPeriod * 6n;

      const tx = await subscriptionManager.updateSBTs([
        {
          sbt: await newSbt.getAddress(),
          subscriptionDurationPerToken: subscriptionDurationPerToken,
        },
        {
          sbt: await sbt.getAddress(),
          subscriptionDurationPerToken: 0n,
        },
      ]);

      await expect(tx)
        .to.emit(subscriptionManager, "SBTAdded")
        .withArgs(await newSbt.getAddress());
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionDurationPerSBTUpdated")
        .withArgs(await newSbt.getAddress(), subscriptionDurationPerToken);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionDurationPerSBTUpdated")
        .withArgs(await sbt.getAddress(), 0n);

      expect(await subscriptionManager.isSupportedSBT(newSbt)).to.be.true;
      expect(await subscriptionManager.isSupportedSBT(sbt)).to.be.true;
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(
        subscriptionManager.connect(FIRST).updateSBTs([
          {
            sbt: FIRST.address,
            subscriptionDurationPerToken: basePaymentPeriod * 6n,
          },
        ]),
      )
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#removeSBTs", () => {
    it("should correctly remove sbt tokens", async () => {
      const tx = await subscriptionManager.removeSBTs([await sbt.getAddress()]);

      expect(await subscriptionManager.isSupportedSBT(sbt)).to.be.false;

      await expect(tx)
        .to.emit(subscriptionManager, "SBTRemoved")
        .withArgs(await sbt.getAddress());
    });

    it("should get exception if try to remove not supported sbt token", async () => {
      const newSbt = await ethers.deployContract("SBTMock");

      await expect(subscriptionManager.removeSBTs([await newSbt.getAddress()]))
        .to.be.revertedWithCustomError(subscriptionManager, "NotSupportedSBT")
        .withArgs(await newSbt.getAddress());
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).removeSBTs([await sbt.getAddress()]))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#addSubscriptionCreators", async () => {
    it("should correctly add new subscription creator", async () => {
      const tx = await subscriptionManager.addSubscriptionCreators([FIRST]);

      expect(await subscriptionManager.getSubscriptionCreators()).to.be.deep.eq([
        await recoveryManager.getAddress(),
        FIRST.address,
      ]);
      expect(await subscriptionManager.isSubscriptionCreator(FIRST)).to.be.true;

      await expect(tx).to.emit(subscriptionManager, "SubscriptionCreatorAdded").withArgs(FIRST.address);
    });

    it("should get exception if pass zero address", async () => {
      await expect(subscriptionManager.addSubscriptionCreators([ethers.ZeroAddress]))
        .to.be.revertedWithCustomError(subscriptionManager, "ZeroAddr")
        .withArgs("SubscriptionCreator");
    });

    it("should get exception if try to add already existing subscription creator", async () => {
      await subscriptionManager.addSubscriptionCreators([FIRST]);

      await expect(subscriptionManager.addSubscriptionCreators([FIRST]))
        .to.be.revertedWithCustomError(subscriptionManager, "SubscriptionCreatorAlreadyAdded")
        .withArgs(FIRST.address);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).addSubscriptionCreators([FIRST]))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#removeSubscriptionCreators", async () => {
    it("should correctly remove subscription creator", async () => {
      await subscriptionManager.addSubscriptionCreators([FIRST]);

      const tx = await subscriptionManager.removeSubscriptionCreators([FIRST]);

      expect(await subscriptionManager.getSubscriptionCreators()).to.be.deep.eq([await recoveryManager.getAddress()]);
      expect(await subscriptionManager.isSubscriptionCreator(FIRST)).to.be.false;

      await expect(tx).to.emit(subscriptionManager, "SubscriptionCreatorRemoved").withArgs(FIRST.address);
    });

    it("should get exception if try to remove not existing subscription creator", async () => {
      await expect(subscriptionManager.removeSubscriptionCreators([FIRST]))
        .to.be.revertedWithCustomError(subscriptionManager, "NotASubscriptionCreator")
        .withArgs(FIRST.address);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(subscriptionManager.connect(FIRST).removeSubscriptionCreators([FIRST]))
        .to.be.revertedWithCustomError(subscriptionManager, "OwnableUnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("#createSubscription", () => {
    it("should create subscription correctly", async () => {
      const tx = await recoveryManager.createSubscription(subscriptionManager, FIRST);

      const timestamp = await time.latest();

      await expect(tx).to.emit(subscriptionManager, "SubscriptionCreated").withArgs(FIRST.address, timestamp);

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(timestamp);
      expect(await subscriptionManager.hasSubscription(FIRST)).to.be.true;
      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.false;
      expect(await subscriptionManager.hasSubscriptionDebt(FIRST)).to.be.true;
    });

    it("should get exception if try to create already existing subscription", async () => {
      await recoveryManager.createSubscription(subscriptionManager, FIRST);

      await expect(recoveryManager.createSubscription(subscriptionManager, FIRST))
        .to.be.revertedWithCustomError(subscriptionManager, "SubscriptionAlreadyCreated")
        .withArgs(FIRST.address);
    });

    it("should not allow to create subscription if the caller is not the subscription creator", async () => {
      await expect(subscriptionManager.connect(FIRST).createSubscription(FIRST))
        .to.be.revertedWithCustomError(subscriptionManager, "NotASubscriptionCreator")
        .withArgs(FIRST.address);
    });
  });

  describe("#buySubscription", () => {
    it("should correctly buy subscription for 2 base periods", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), OWNER, expectedCost);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-expectedCost, expectedCost],
      );

      await subscriptionManager.updatePaymentTokens([
        {
          paymentToken: await paymentToken.getAddress(),
          baseSubscriptionCost: paymentTokenSubscriptionCost * 2n,
        },
      ]);

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
      expect(await subscriptionManager.getAccountBaseSubscriptionCost(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );
      expect(await subscriptionManager.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost * 2n,
      );
    });

    it("should correctly buy subscription for 2.5 base periods", async () => {
      const duration = (basePaymentPeriod * 5n) / 2n;
      const expectedCost = (paymentTokenSubscriptionCost * 5n) / 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), OWNER, expectedCost);
      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [OWNER, subscriptionManager],
        [-expectedCost, expectedCost],
      );

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
    });

    it("should correctly buy and extend subscription", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost * 2n);
      await paymentToken.approve(subscriptionManager, expectedCost * 2n);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration * 2n;

      await time.setNextBlockTimestamp(startTime);
      let tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx)
        .to.emit(subscriptionManager, "AccountTokenSubscriptionCostUpdated")
        .withArgs(FIRST.address, await paymentToken.getAddress(), paymentTokenSubscriptionCost);

      tx = await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      await expect(tx).to.not.emit(subscriptionManager, "AccountTokenSubscriptionCostUpdated");

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);
    });

    it("should get exception if payment token is not available", async () => {
      const newToken = await ethers.deployContract("ERC20Mock", ["Test ERC20 2", "TT2", 18]);

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, newToken, basePaymentPeriod))
        .to.be.revertedWithCustomError(subscriptionManager, "TokenNotSupported")
        .withArgs(await newToken.getAddress());
    });

    it("should get exception if pass duration that less than the base period", async () => {
      const invalidDuration = basePaymentPeriod / 2n;

      await expect(subscriptionManager.connect(FIRST).buySubscription(FIRST, ETHER_ADDR, invalidDuration))
        .to.be.revertedWithCustomError(subscriptionManager, "InvalidSubscriptionDuration")
        .withArgs(invalidDuration);
    });
  });

  describe("#buySubscriptionWithSBT", () => {
    const tokenId = 1n;

    beforeEach("setup", async () => {
      await sbt.mint(FIRST, tokenId);
    });

    it("should correctly buy subscription with SBT token", async () => {
      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + sbtSubscriptionDuration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.connect(FIRST).buySubscriptionWithSBT(FIRST, sbt, tokenId);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSBT")
        .withArgs(await sbt.getAddress(), FIRST.address, tokenId);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, sbtSubscriptionDuration, expectedEndTime);

      expect(await subscriptionManager.hasActiveSubscription(FIRST)).to.be.true;
      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await expect(sbt.ownerOf(tokenId)).to.be.revertedWithCustomError(sbt, "ERC721NonexistentToken").withArgs(tokenId);
    });

    it("should correctly extend subscription with SBT token", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = paymentTokenSubscriptionCost * 2n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(subscriptionManager, expectedCost);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      await subscriptionManager.buySubscription(FIRST, paymentToken, duration);

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(expectedEndTime);

      await subscriptionManager.connect(FIRST).buySubscriptionWithSBT(FIRST, sbt, tokenId);

      expect(await subscriptionManager.getSubscriptionEndTime(FIRST)).to.be.eq(
        expectedEndTime + sbtSubscriptionDuration,
      );
    });

    it("should get exception if pass unsupported SBT token address", async () => {
      const newSbtToken = await ethers.deployContract("SBTMock");
      await newSbtToken.mint(FIRST, tokenId);

      await expect(subscriptionManager.buySubscriptionWithSBT(FIRST, newSbtToken, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotSupportedSBT")
        .withArgs(await newSbtToken.getAddress());
    });

    it("should get exception if pass invalid token id", async () => {
      await expect(subscriptionManager.connect(SECOND).buySubscriptionWithSBT(FIRST, sbt, tokenId))
        .to.be.revertedWithCustomError(subscriptionManager, "NotASBTOwner")
        .withArgs(await sbt.getAddress(), SECOND.address, tokenId);
    });
  });

  describe("#buySubscriptionWithSignature", () => {
    it("should correctly buy subscription with signature", async () => {
      const duration = basePaymentPeriod * 12n;

      const currentNonce = await subscriptionManager.nonces(OWNER);
      const signature = await getBuySubscriptionSignature(subscriptionManager, SUBSCRIPTION_SIGNER, {
        sender: OWNER.address,
        duration: duration,
        nonce: currentNonce,
      });

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await subscriptionManager.buySubscriptionWithSignature(FIRST, duration, signature);

      expect(await subscriptionManager.nonces(OWNER)).to.be.eq(currentNonce + 1n);

      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionBoughtWithSignature")
        .withArgs(OWNER.address, duration, currentNonce);
      await expect(tx)
        .to.emit(subscriptionManager, "SubscriptionExtended")
        .withArgs(FIRST.address, duration, expectedEndTime);
    });
  });
});
