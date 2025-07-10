import { ETHER_ADDR, wei } from "@/scripts";
import { ERC20Mock, PriceManager, TokensPriceModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("TokensWhitelistModule", () => {
  const reverter = new Reverter();

  let usdToken: ERC20Mock;
  let priceManager: PriceManager;
  let tokensPriceModule: TokensPriceModuleMock;

  before(async () => {
    usdToken = await ethers.deployContract("ERC20Mock", ["USD Token", "USD", 18]);
    priceManager = await ethers.deployContract("PriceManager");
    tokensPriceModule = await ethers.deployContract("TokensPriceModuleMock");

    await priceManager.initialize(await usdToken.getAddress());

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("setPriceManager", () => {
    it("should correctly set the price manager", async () => {
      expect(await tokensPriceModule.tokensPriceManager()).to.equal(ethers.ZeroAddress);

      const priceManagerAddress = await priceManager.getAddress();
      const tx = await tokensPriceModule.setPriceManager(priceManagerAddress);

      expect(await tokensPriceModule.tokensPriceManager()).to.equal(priceManagerAddress);

      await expect(tx).to.emit(tokensPriceModule, "PriceManagerUpdated").withArgs(priceManagerAddress);
    });

    it("should revert if trying to set the price manager to zero address", async () => {
      await expect(tokensPriceModule.setPriceManager(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        tokensPriceModule,
        "InvalidPriceManagerAddress",
      );
    });
  });

  describe("getters", () => {
    it("should return correct data from getters", async () => {
      await tokensPriceModule.setPriceManager(await priceManager.getAddress());

      expect(await tokensPriceModule.tokensPriceManager()).to.equal(await priceManager.getAddress());
      expect(await tokensPriceModule.isTokenSupported(await usdToken.getAddress())).to.be.true;
      expect(await tokensPriceModule.isNativeToken(ETHER_ADDR)).to.be.true;

      const usdTokenAddress = await usdToken.getAddress();
      const usdAmount = wei(1000);
      expect(await tokensPriceModule.getAmountFromUsd(usdTokenAddress, usdAmount)).to.be.eq(usdAmount);
      expect(await tokensPriceModule.getAmountInUsd(usdTokenAddress, usdAmount)).to.be.eq(usdAmount);
    });
  });
});
