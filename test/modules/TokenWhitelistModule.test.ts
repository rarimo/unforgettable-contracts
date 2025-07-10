import { ERC20Mock, PriceManager, TokensWhitelistModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("TokensWhitelistModule", () => {
  const reverter = new Reverter();

  let usdToken: ERC20Mock;
  let priceManager: PriceManager;
  let whitelistModule: TokensWhitelistModuleMock;

  before(async () => {
    usdToken = await ethers.deployContract("ERC20Mock", ["USD Token", "USD", 18]);
    priceManager = await ethers.deployContract("PriceManager");
    whitelistModule = await ethers.deployContract("TokensWhitelistModuleMock");

    await priceManager.initialize(await usdToken.getAddress());

    await whitelistModule.setPriceManager(await priceManager.getAddress());

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("initialize", () => {
    it("should correctly set initial values", async () => {
      expect(await whitelistModule.tokensPriceManager()).to.equal(await priceManager.getAddress());
      expect(await whitelistModule.isTokenSupported(await usdToken.getAddress())).to.be.true;
    });
  });

  describe("addTokensToWhitelist", () => {
    it("should correctly add tokens to the whitelist", async () => {
      expect(await whitelistModule.isTokenWhitelisted(await usdToken.getAddress())).to.be.false;

      const tx = await whitelistModule.addTokensToWhitelist([await usdToken.getAddress()]);

      expect(await whitelistModule.isTokenWhitelisted(await usdToken.getAddress())).to.be.true;

      await expect(tx)
        .to.emit(whitelistModule, "TokensWhitelisted")
        .withArgs([await usdToken.getAddress()]);

      expect(await whitelistModule.getWhitelistedTokens()).to.deep.equal([await usdToken.getAddress()]);
    });

    it("should get exception if try to add token that is not supported", async () => {
      const unsupportedToken = await ethers.deployContract("ERC20Mock", ["Unsupported Token", "UNSUP", 18]);

      await expect(whitelistModule.addTokensToWhitelist([await unsupportedToken.getAddress()]))
        .to.be.revertedWithCustomError(whitelistModule, "UnsupportedToken")
        .withArgs(await unsupportedToken.getAddress());
    });
  });

  describe("removeTokensFromWhitelist", () => {
    it("should correctly remove tokens from the whitelist", async () => {
      const usdTokenAddress = await usdToken.getAddress();
      await whitelistModule.addTokensToWhitelist([usdTokenAddress]);

      expect(await whitelistModule.isTokenWhitelisted(usdTokenAddress)).to.be.true;

      const tx = await whitelistModule.removeTokensFromWhitelist([usdTokenAddress]);

      expect(await whitelistModule.isTokenWhitelisted(usdTokenAddress)).to.be.false;

      await expect(tx).to.emit(whitelistModule, "TokensUnwhitelisted").withArgs([usdTokenAddress]);

      expect(await whitelistModule.getWhitelistedTokens()).to.deep.equal([]);
      expect(await whitelistModule.getWhitelistedTokensCount()).to.equal(0);
    });

    it("should get exception if try to remove token that is not whitelisted", async () => {
      const usdTokenAddress = await usdToken.getAddress();

      await expect(whitelistModule.removeTokensFromWhitelist([usdTokenAddress]))
        .to.be.revertedWithCustomError(whitelistModule, "NotAWhitelistedToken")
        .withArgs(usdTokenAddress);
    });
  });
});
