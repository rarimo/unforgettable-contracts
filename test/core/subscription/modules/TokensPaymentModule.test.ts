import { ETHER_ADDR, PERCENTAGE_100, PRECISION, wei } from "@/scripts";
import { ERC20Mock, SBTMock, TokensPaymentModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("TokensPaymentModule", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;

  const nativeSubscriptionCost = wei(1, 15);
  const paymentTokenSubscriptionCost = wei(5);

  const oneYear = basePaymentPeriod * 12n;
  const oneYearFactor = PRECISION * 95n;

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;

  let paymentToken: ERC20Mock;
  let tokensPaymentModule: TokensPaymentModuleMock;

  let discountSBT: SBTMock;

  beforeEach(async () => {
    [OWNER, FIRST] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);
    tokensPaymentModule = await ethers.deployContract("TokensPaymentModuleMock");

    discountSBT = await ethers.deployContract("SBTMock");

    await discountSBT.initialize("DiscountSBT", "DSBT", [OWNER]);

    await tokensPaymentModule.initialize({
      basePaymentPeriod: basePaymentPeriod,
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: nativeSubscriptionCost,
        },
        {
          paymentToken: paymentToken,
          baseSubscriptionCost: paymentTokenSubscriptionCost,
        },
      ],
      durationFactorEntries: [
        {
          duration: oneYear,
          factor: oneYearFactor,
        },
      ],
      discountEntries: [
        {
          sbtAddr: discountSBT,
          discount: PERCENTAGE_100 / 2n,
        },
      ],
    });

    await paymentToken.mint(OWNER, initialTokensAmount);
    await paymentToken.mint(FIRST, initialTokensAmount);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await tokensPaymentModule.getBasePaymentPeriod()).to.be.eq(basePaymentPeriod);

      expect(await tokensPaymentModule.getPaymentTokens()).to.be.deep.eq([ETHER_ADDR, await paymentToken.getAddress()]);

      expect(await tokensPaymentModule.isSupportedToken(ETHER_ADDR)).to.be.true;
      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(nativeSubscriptionCost);

      expect(await tokensPaymentModule.isSupportedToken(paymentToken)).to.be.true;
      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      expect(await tokensPaymentModule.getSubscriptionDurationFactor(oneYear)).to.be.eq(oneYearFactor);

      expect(await tokensPaymentModule.getDiscountSBTs()).to.be.deep.eq([await discountSBT.getAddress()]);
      expect(await tokensPaymentModule.getDiscount(discountSBT)).to.be.eq(PERCENTAGE_100 / 2n);
    });

    it("should get exception if try to call init function directly", async () => {
      await expect(
        tokensPaymentModule.__TokensPaymentModule_init({
          basePaymentPeriod: basePaymentPeriod / 12n,
          paymentTokenEntries: [],
          durationFactorEntries: [],
          discountEntries: [],
        }),
      ).to.be.revertedWithCustomError(tokensPaymentModule, "NotInitializing");
    });
  });

  describe("#setBasePaymentPeriod", async () => {
    it("should correctly set base payment period", async () => {
      const newBasePaymentPeriod = basePaymentPeriod * 3n;

      const tx = await tokensPaymentModule.setBasePaymentPeriod(newBasePaymentPeriod);

      expect(await tokensPaymentModule.getBasePaymentPeriod()).to.be.eq(newBasePaymentPeriod);

      await expect(tx).to.emit(tokensPaymentModule, "BasePaymentPeriodUpdated").withArgs(newBasePaymentPeriod);
    });
  });

  describe("#updateDurationFactor", async () => {
    it("should correctly update duration factors", async () => {
      const twoYears = oneYear * 2n;
      const twoYearsFactor = PRECISION * 92n;

      expect(await tokensPaymentModule.getSubscriptionDurationFactor(twoYears)).to.be.eq(0n);

      let tx = await tokensPaymentModule.updateDurationFactor(twoYears, twoYearsFactor);

      expect(await tokensPaymentModule.getSubscriptionDurationFactor(twoYears)).to.be.eq(twoYearsFactor);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionDurationFactorUpdated")
        .withArgs(twoYears, twoYearsFactor);

      tx = await tokensPaymentModule.updateDurationFactor(oneYear, 0n);

      expect(await tokensPaymentModule.getSubscriptionDurationFactor(oneYear)).to.be.eq(0n);

      await expect(tx).to.emit(tokensPaymentModule, "SubscriptionDurationFactorUpdated").withArgs(oneYear, 0n);
    });
  });

  describe("#updateDiscount", async () => {
    it("should correctly update discounts", async () => {
      let tx = await tokensPaymentModule.updateDiscount(paymentToken, 200);

      await expect(tx)
        .to.emit(tokensPaymentModule, "DiscountUpdated")
        .withArgs(await paymentToken.getAddress(), 200);

      expect(await tokensPaymentModule.getDiscountSBTs()).to.be.deep.eq([
        await discountSBT.getAddress(),
        await paymentToken.getAddress(),
      ]);
      expect(await tokensPaymentModule.getDiscount(paymentToken)).to.be.eq(200);
      expect(await tokensPaymentModule.getDiscount(discountSBT)).to.be.eq(PERCENTAGE_100 / 2n);

      tx = await tokensPaymentModule.updateDiscount(discountSBT, 350n);

      await expect(tx)
        .to.emit(tokensPaymentModule, "DiscountUpdated")
        .withArgs(await discountSBT.getAddress(), 350);

      expect(await tokensPaymentModule.getDiscountSBTs()).to.be.deep.eq([
        await discountSBT.getAddress(),
        await paymentToken.getAddress(),
      ]);
      expect(await tokensPaymentModule.getDiscount(paymentToken)).to.be.eq(200);
      expect(await tokensPaymentModule.getDiscount(discountSBT)).to.be.eq(350);

      tx = await tokensPaymentModule.updateDiscount(discountSBT, 0);

      await expect(tx)
        .to.emit(tokensPaymentModule, "DiscountUpdated")
        .withArgs(await discountSBT.getAddress(), 0);

      expect(await tokensPaymentModule.getDiscountSBTs()).to.be.deep.eq([await paymentToken.getAddress()]);
      expect(await tokensPaymentModule.getDiscount(paymentToken)).to.be.eq(200);
      expect(await tokensPaymentModule.getDiscount(discountSBT)).to.be.eq(0);
    });

    it("should get exception if try to set invalid discount", async () => {
      await expect(tokensPaymentModule.updateDiscount(discountSBT, PERCENTAGE_100 * 2n))
        .to.be.revertedWithCustomError(tokensPaymentModule, "InvalidDiscountValue")
        .withArgs(PERCENTAGE_100 * 2n);
    });
  });

  describe("#withdrawTokens", async () => {
    it("should correctly withdraw ERC20 tokens", async () => {
      await paymentToken.mint(tokensPaymentModule, initialTokensAmount);

      const amountToWithdraw = initialTokensAmount / 2n;

      const tx = await tokensPaymentModule.withdrawTokens(paymentToken, FIRST, amountToWithdraw);

      await expect(tx)
        .to.emit(tokensPaymentModule, "TokensWithdrawn")
        .withArgs(await paymentToken.getAddress(), FIRST.address, amountToWithdraw);

      await expect(tx).to.changeTokenBalances(
        paymentToken,
        [await tokensPaymentModule.getAddress(), FIRST.address],
        [-amountToWithdraw, amountToWithdraw],
      );

      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(initialTokensAmount - amountToWithdraw);
      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount + amountToWithdraw);
    });

    it("should correctly withdraw native tokens", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, ETHER_ADDR, duration);

      await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, ETHER_ADDR, duration, { value: expectedCost });

      expect(await ethers.provider.getBalance(tokensPaymentModule)).to.be.eq(expectedCost);

      const amountToWithdraw = expectedCost / 2n;

      const tx = await tokensPaymentModule.withdrawTokens(ETHER_ADDR, FIRST, amountToWithdraw);

      await expect(tx)
        .to.emit(tokensPaymentModule, "TokensWithdrawn")
        .withArgs(ETHER_ADDR, FIRST.address, amountToWithdraw);

      await expect(tx).to.changeEtherBalances(
        [await tokensPaymentModule.getAddress(), FIRST.address],
        [-amountToWithdraw, amountToWithdraw],
      );
    });

    it("should get exception if pass zero address", async () => {
      await paymentToken.mint(tokensPaymentModule, initialTokensAmount);

      const amountToWithdraw = initialTokensAmount / 2n;

      await expect(tokensPaymentModule.withdrawTokens(paymentToken, ethers.ZeroAddress, amountToWithdraw))
        .to.be.revertedWithCustomError(tokensPaymentModule, "ZeroAddr")
        .withArgs("To");
    });
  });

  describe("#updatePaymentToken", () => {
    it("should correctly add payment token and set base subscription cost", async () => {
      const newPaymentToken = await ethers.deployContract("ERC20Mock", ["Test Token2", "TT2", 18]);
      const newPaymentTokenSubscriptionCost = wei(7);

      const tx = await tokensPaymentModule.updatePaymentToken(newPaymentToken, newPaymentTokenSubscriptionCost);

      await expect(tx)
        .to.emit(tokensPaymentModule, "PaymentTokenAdded")
        .withArgs(await newPaymentToken.getAddress());
      await expect(tx)
        .to.emit(tokensPaymentModule, "BaseSubscriptionCostUpdated")
        .withArgs(await newPaymentToken.getAddress(), newPaymentTokenSubscriptionCost);

      expect(await tokensPaymentModule.isSupportedToken(newPaymentToken)).to.be.true;
      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(newPaymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );
    });

    it("should correctly update existing payment token base subscription cost", async () => {
      const newBaseSubscriptionCost = paymentTokenSubscriptionCost * 2n;

      const tx = await tokensPaymentModule.updatePaymentToken(paymentToken, newBaseSubscriptionCost);

      await expect(tx).to.not.emit(tokensPaymentModule, "PaymentTokenAdded");
      await expect(tx)
        .to.emit(tokensPaymentModule, "BaseSubscriptionCostUpdated")
        .withArgs(await paymentToken.getAddress(), newBaseSubscriptionCost);

      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(newBaseSubscriptionCost);
    });
  });

  describe("#addPaymentToken", () => {
    it("should correctly add payment token contract", async () => {
      const newPaymentToken = await ethers.deployContract("ERC20Mock", ["Test Token2", "TT2", 18]);

      const tx = await tokensPaymentModule.addPaymentToken(newPaymentToken);

      await expect(tx)
        .to.emit(tokensPaymentModule, "PaymentTokenAdded")
        .withArgs(await newPaymentToken.getAddress());

      expect(await tokensPaymentModule.isSupportedToken(newPaymentToken)).to.be.true;
      expect(await tokensPaymentModule.getPaymentTokens()).to.be.deep.eq([
        ETHER_ADDR,
        await paymentToken.getAddress(),
        await newPaymentToken.getAddress(),
      ]);
    });

    it("should get exception if try to add existing payment token", async () => {
      await expect(tokensPaymentModule.addPaymentToken(paymentToken))
        .to.revertedWithCustomError(tokensPaymentModule, "PaymentTokenAlreadyAdded")
        .withArgs(await paymentToken.getAddress());
    });

    it("should get exception if try to add zero address", async () => {
      await expect(tokensPaymentModule.addPaymentToken(ethers.ZeroAddress))
        .to.revertedWithCustomError(tokensPaymentModule, "ZeroAddr")
        .withArgs("PaymentToken");
    });
  });

  describe("#removePaymentToken", () => {
    it("should correctly remove payment token", async () => {
      const tx = await tokensPaymentModule.removePaymentToken(ETHER_ADDR);

      await expect(tx).to.emit(tokensPaymentModule, "PaymentTokenRemoved").withArgs(ETHER_ADDR);

      expect(await tokensPaymentModule.isSupportedToken(ETHER_ADDR)).to.be.false;
      expect(await tokensPaymentModule.getPaymentTokens()).to.be.deep.eq([await paymentToken.getAddress()]);
      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(ETHER_ADDR)).to.be.eq(0n);
    });

    it("should get exception if try to remove unsupported payment token", async () => {
      const newPaymentToken = await ethers.deployContract("ERC20Mock", ["Test Token2", "TT2", 18]);

      expect(await tokensPaymentModule.isSupportedToken(newPaymentToken)).to.be.false;

      await expect(tokensPaymentModule.removePaymentToken(newPaymentToken))
        .to.revertedWithCustomError(tokensPaymentModule, "TokenNotSupported")
        .withArgs(await newPaymentToken.getAddress());
    });
  });

  describe("#buySubscription", () => {
    it("should correctly buy subscription with native token", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, ETHER_ADDR, duration);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      expect(await ethers.provider.getBalance(tokensPaymentModule)).to.be.eq(0n);

      await time.setNextBlockTimestamp(startTime);
      const tx = await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, ETHER_ADDR, duration, {
        value: expectedCost,
      });

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(ETHER_ADDR, FIRST.address, expectedCost);

      expect(await ethers.provider.getBalance(tokensPaymentModule)).to.be.eq(expectedCost);

      expect(await tokensPaymentModule.getSubscriptionStartTime(OWNER)).to.be.eq(startTime);
      expect(await tokensPaymentModule.getSubscriptionEndTime(OWNER)).to.be.eq(expectedEndTime);

      expect(await tokensPaymentModule.hasSubscription(OWNER)).to.be.true;
      expect(await tokensPaymentModule.hasActiveSubscription(OWNER)).to.be.true;
    });

    it("should correctly buy subscription with ERC20 token", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration);

      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount);
      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(0n);

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, expectedCost);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, paymentToken, duration);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), FIRST.address, expectedCost);

      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(expectedCost);
      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount - expectedCost);

      expect(await tokensPaymentModule.getSubscriptionStartTime(OWNER)).to.be.eq(startTime);
      expect(await tokensPaymentModule.getSubscriptionEndTime(OWNER)).to.be.eq(expectedEndTime);

      expect(await tokensPaymentModule.hasSubscription(OWNER)).to.be.true;
      expect(await tokensPaymentModule.hasActiveSubscription(OWNER)).to.be.true;
    });

    it("should correctly extend subscription", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration);

      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount);
      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(0n);

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, expectedCost);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      await time.setNextBlockTimestamp(startTime);
      await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, paymentToken, duration);

      expect(await tokensPaymentModule.getSubscriptionStartTime(OWNER)).to.be.eq(startTime);
      expect(await tokensPaymentModule.getSubscriptionEndTime(OWNER)).to.be.eq(expectedEndTime);

      expect(await tokensPaymentModule.hasSubscription(OWNER)).to.be.true;
      expect(await tokensPaymentModule.hasActiveSubscription(OWNER)).to.be.true;

      const newDuration = basePaymentPeriod * 3n;
      const newExpectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, newDuration);

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, newExpectedCost);

      const newExpectedEndTime = expectedEndTime + newDuration;

      const tx = await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, paymentToken, newDuration);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, newDuration, newExpectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), FIRST.address, newExpectedCost);

      expect(await tokensPaymentModule.getSubscriptionStartTime(OWNER)).to.be.eq(startTime);
      expect(await tokensPaymentModule.getSubscriptionEndTime(OWNER)).to.be.eq(newExpectedEndTime);

      expect(await tokensPaymentModule.hasSubscription(OWNER)).to.be.true;
    });

    it("should correctly save token subscription cost", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration);

      expect(await tokensPaymentModule.getAccountSavedSubscriptionCost(OWNER, paymentToken)).to.be.eq(0n);

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, expectedCost);
      await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, paymentToken, duration);

      expect(await tokensPaymentModule.getAccountSavedSubscriptionCost(OWNER, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );
    });

    it("should correctly buy subscription with duration factor", async () => {
      const duration = oneYear;
      const expectedCost = await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration);

      expect(expectedCost).to.be.eq(
        ((oneYear / basePaymentPeriod) * paymentTokenSubscriptionCost * oneYearFactor) / PERCENTAGE_100,
      );

      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount);
      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(0n);

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, expectedCost);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await tokensPaymentModule.connect(FIRST).buySubscription(OWNER, paymentToken, duration);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), FIRST.address, expectedCost);

      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(expectedCost);
      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount - expectedCost);
    });

    it("should get exception if duration is less than the base payment period", async () => {
      const duration = basePaymentPeriod / 2n;

      await expect(tokensPaymentModule.connect(FIRST).buySubscription(OWNER, ETHER_ADDR, duration))
        .to.be.revertedWithCustomError(tokensPaymentModule, "InvalidSubscriptionDuration")
        .withArgs(duration);
    });

    it("should get exception if pass unsupported payment token", async () => {
      const unsupportedToken = await ethers.deployContract("ERC20Mock", ["Unsupported Token", "UT", 18]);
      const duration = basePaymentPeriod * 2n;

      await expect(tokensPaymentModule.connect(FIRST).buySubscription(OWNER, unsupportedToken, duration))
        .to.be.revertedWithCustomError(tokensPaymentModule, "TokenNotSupported")
        .withArgs(await unsupportedToken.getAddress());
    });
  });

  describe("#buySubscriptionWithDiscount", () => {
    it("should correctly buy subscription with native token with discount", async () => {
      const duration = basePaymentPeriod * 4n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCostWithDiscount(
        FIRST,
        ETHER_ADDR,
        duration,
        discountSBT,
      );

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      expect(await ethers.provider.getBalance(tokensPaymentModule)).to.be.eq(0n);

      await discountSBT.connect(OWNER).mint(FIRST, 2);

      const discountData = {
        sbtAddr: await discountSBT.getAddress(),
        tokenId: 2,
      };

      await time.setNextBlockTimestamp(startTime);
      const tx = await tokensPaymentModule
        .connect(FIRST)
        .buySubscriptionWithDiscount(OWNER, ETHER_ADDR, duration, discountData, {
          value: expectedCost,
        });

      expect(await ethers.provider.getBalance(tokensPaymentModule)).to.be.eq(expectedCost);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(ETHER_ADDR, FIRST.address, expectedCost);
    });

    it("should correctly buy subscription with ERC20 token with discount", async () => {
      const duration = basePaymentPeriod * 2n;
      const expectedCost = await tokensPaymentModule.getSubscriptionCostWithDiscount(
        FIRST,
        paymentToken,
        duration,
        discountSBT,
      );

      await paymentToken.connect(FIRST).approve(tokensPaymentModule, expectedCost);

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      await discountSBT.connect(OWNER).mint(FIRST, 1);

      const discountData = {
        sbtAddr: await discountSBT.getAddress(),
        tokenId: 1,
      };

      await time.setNextBlockTimestamp(startTime);
      const tx = await tokensPaymentModule
        .connect(FIRST)
        .buySubscriptionWithDiscount(OWNER, paymentToken, duration, discountData);

      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(tokensPaymentModule, "SubscriptionBoughtWithToken")
        .withArgs(await paymentToken.getAddress(), FIRST.address, expectedCost);

      expect(await paymentToken.balanceOf(tokensPaymentModule)).to.be.eq(expectedCost);
      expect(await paymentToken.balanceOf(FIRST)).to.be.eq(initialTokensAmount - expectedCost);
    });

    it("should get exception if pass unsupported discount SBT", async () => {
      const discountData = {
        sbtAddr: await paymentToken.getAddress(),
        tokenId: 1,
      };

      await expect(
        tokensPaymentModule
          .connect(FIRST)
          .buySubscriptionWithDiscount(OWNER, paymentToken, basePaymentPeriod * 2n, discountData),
      )
        .to.be.revertedWithCustomError(tokensPaymentModule, "InvalidDiscountSBT")
        .withArgs(await paymentToken.getAddress());
    });

    it("should get exception if the caller is not the owner of the discount SBT", async () => {
      await discountSBT.connect(OWNER).mint(OWNER, 1);

      const discountData = {
        sbtAddr: await discountSBT.getAddress(),
        tokenId: 1,
      };

      await expect(
        tokensPaymentModule
          .connect(FIRST)
          .buySubscriptionWithDiscount(OWNER, paymentToken, basePaymentPeriod * 2n, discountData),
      )
        .to.be.revertedWithCustomError(tokensPaymentModule, "NotADiscountSBTOwner")
        .withArgs(await discountSBT.getAddress(), FIRST.address, 1);
    });

    it("should get exception if pass unsupported payment token", async () => {
      const unsupportedToken = await ethers.deployContract("ERC20Mock", ["Unsupported Token", "UT", 18]);
      const duration = basePaymentPeriod * 2n;

      const discountData = {
        sbtAddr: await discountSBT.getAddress(),
        tokenId: 1,
      };

      await expect(
        tokensPaymentModule.connect(FIRST).buySubscriptionWithDiscount(OWNER, unsupportedToken, duration, discountData),
      )
        .to.be.revertedWithCustomError(tokensPaymentModule, "TokenNotSupported")
        .withArgs(await unsupportedToken.getAddress());
    });
  });

  describe("#getSubscriptionCost", () => {
    it("should correctly count subscription cost for different periods", async () => {
      let duration = basePaymentPeriod * 3n;
      let expectedCost = paymentTokenSubscriptionCost * 3n;

      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);

      duration = basePaymentPeriod * 5n + basePaymentPeriod / 2n;
      expectedCost = paymentTokenSubscriptionCost * 5n + paymentTokenSubscriptionCost / 2n;

      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost using stored account price", async () => {
      const duration = basePaymentPeriod * 3n;
      const expectedCost = paymentTokenSubscriptionCost * 3n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(tokensPaymentModule, expectedCost);

      await tokensPaymentModule.buySubscription(FIRST, paymentToken, duration);

      expect(await tokensPaymentModule.getAccountBaseSubscriptionCost(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      const newPaymentTokenSubscriptionCost = paymentTokenSubscriptionCost * 2n;

      await tokensPaymentModule.updatePaymentToken(paymentToken, newPaymentTokenSubscriptionCost);

      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );

      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost when current cost < stored cost", async () => {
      const duration = basePaymentPeriod * 3n;
      let expectedCost = paymentTokenSubscriptionCost * 3n;

      await paymentToken.mint(OWNER, expectedCost);
      await paymentToken.approve(tokensPaymentModule, expectedCost);

      await tokensPaymentModule.buySubscription(FIRST, paymentToken, duration);

      expect(await tokensPaymentModule.getAccountBaseSubscriptionCost(FIRST, paymentToken)).to.be.eq(
        paymentTokenSubscriptionCost,
      );

      const newPaymentTokenSubscriptionCost = paymentTokenSubscriptionCost / 2n;

      await tokensPaymentModule.updatePaymentToken(paymentToken, newPaymentTokenSubscriptionCost);

      expect(await tokensPaymentModule.getAccountBaseSubscriptionCost(FIRST, paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );
      expect(await tokensPaymentModule.getTokenBaseSubscriptionCost(paymentToken)).to.be.eq(
        newPaymentTokenSubscriptionCost,
      );

      expectedCost = newPaymentTokenSubscriptionCost * 3n;

      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(expectedCost);
    });

    it("should correctly count subscription cost with duration factor", async () => {
      const duration = basePaymentPeriod * 6n;
      const factor = PRECISION * 97n;

      const expectedCostWithoutFactor = paymentTokenSubscriptionCost * 6n;
      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithoutFactor,
      );

      await tokensPaymentModule.updateDurationFactor(duration, factor);

      const expectedCostWithFactor = (expectedCostWithoutFactor * factor) / PERCENTAGE_100;
      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithFactor,
      );

      await paymentToken.mint(OWNER, expectedCostWithFactor);
      await paymentToken.approve(tokensPaymentModule, expectedCostWithFactor);

      const startTime = (await time.latest()) + 100;
      const expectedEndTime = BigInt(startTime) + duration;

      await time.setNextBlockTimestamp(startTime);
      await tokensPaymentModule.buySubscription(FIRST, paymentToken, duration);

      await time.increaseTo(expectedEndTime + 100n);

      expect(await tokensPaymentModule.hasSubscriptionDebt(FIRST)).to.be.true;

      expect(await tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, duration)).to.be.eq(
        expectedCostWithoutFactor,
      );
    });

    it("should get exception if pass zero duration", async () => {
      await expect(tokensPaymentModule.getSubscriptionCost(FIRST, paymentToken, 0n)).to.be.revertedWithCustomError(
        tokensPaymentModule,
        "ZeroDuration",
      );
    });

    it("should get exception if pass unsupported token address", async () => {
      await expect(tokensPaymentModule.getSubscriptionCost(FIRST, FIRST, basePaymentPeriod))
        .to.be.revertedWithCustomError(tokensPaymentModule, "TokenNotSupported")
        .withArgs(await FIRST.getAddress());
    });
  });

  describe("#getSubscriptionCostWithDiscount", () => {
    it("should correctly count subscription cost with discount", async () => {
      let duration = basePaymentPeriod * 3n;
      let expectedCost = (paymentTokenSubscriptionCost * 3n) / 2n;

      expect(
        await tokensPaymentModule.getSubscriptionCostWithDiscount(FIRST, paymentToken, duration, discountSBT),
      ).to.be.eq(expectedCost);

      duration = basePaymentPeriod * 5n + basePaymentPeriod / 2n;
      expectedCost = (paymentTokenSubscriptionCost * 5n + paymentTokenSubscriptionCost / 2n) / 2n;

      expect(
        await tokensPaymentModule.getSubscriptionCostWithDiscount(FIRST, paymentToken, duration, discountSBT),
      ).to.be.eq(expectedCost);

      expect(
        await tokensPaymentModule.getSubscriptionCostWithDiscount(FIRST, paymentToken, duration, paymentToken),
      ).to.be.eq(expectedCost * 2n);
    });

    it("should get exception if pass unsupported token address", async () => {
      await expect(tokensPaymentModule.getSubscriptionCostWithDiscount(FIRST, FIRST, basePaymentPeriod, discountSBT))
        .to.be.revertedWithCustomError(tokensPaymentModule, "TokenNotSupported")
        .withArgs(await FIRST.getAddress());
    });
  });
});
