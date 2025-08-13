import { ReservedRMO, VaultFactoryMock } from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("ReservedRMO", () => {
  const reverter = new Reverter();

  const reservedTokensAmountPerAddress = wei(10000);

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let RMO_TOKEN: SignerWithAddress;

  let vaultFactory: VaultFactoryMock;

  let reservedRMOImpl: ReservedRMO;
  let reservedRMO: ReservedRMO;

  beforeEach(async () => {
    [OWNER, FIRST, SECOND, RMO_TOKEN] = await ethers.getSigners();

    vaultFactory = await ethers.deployContract("VaultFactoryMock");

    reservedRMOImpl = await ethers.deployContract("ReservedRMO");
    const reservedRMOProxy = await ethers.deployContract("ERC1967Proxy", [await reservedRMOImpl.getAddress(), "0x"]);

    reservedRMO = await ethers.getContractAt("ReservedRMO", reservedRMOProxy);

    await reservedRMO.initialize(vaultFactory, reservedTokensAmountPerAddress);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#creation", () => {
    it("should set correct initial values", async () => {
      expect(await reservedRMO.name()).to.equal("Reserved RMO");
      expect(await reservedRMO.symbol()).to.equal("rRMO");
      expect(await reservedRMO.owner()).to.equal(OWNER);

      expect(await reservedRMO.getVaultFactory()).to.equal(await vaultFactory.getAddress());
      expect(await reservedRMO.getReservedTokensPerAddress()).to.equal(reservedTokensAmountPerAddress);
      expect(await reservedRMO.getRMOToken()).to.equal(ethers.ZeroAddress);

      expect(await reservedRMO.paused()).to.be.true;
    });

    it("should get exception if pass zero reserved tokens amount", async () => {
      const newReservedRMO = await ethers.deployContract("ReservedRMO");

      await expect(newReservedRMO.initialize(vaultFactory, 0)).to.be.revertedWithCustomError(
        newReservedRMO,
        "ZeroReservedTokensAmountPerAddress",
      );
    });

    it("should get exception when trying to call initialize again", async () => {
      await expect(reservedRMO.initialize(vaultFactory, reservedTokensAmountPerAddress)).to.be.revertedWithCustomError(
        reservedRMO,
        "InvalidInitialization",
      );
    });
  });

  describe("#upgrade", () => {
    it("should upgrade the contract", async () => {
      const newReservedRMOImpl = await ethers.deployContract("ReservedRMO");
      const tx = await reservedRMO.upgradeToAndCall(await newReservedRMOImpl.getAddress(), "0x");

      expect(await reservedRMO.implementation()).to.equal(await newReservedRMOImpl.getAddress());
      await expect(tx)
        .to.emit(reservedRMO, "Upgraded")
        .withArgs(await newReservedRMOImpl.getAddress());
    });

    it("should get exception if not called by owner", async () => {
      const newReservedRMOImpl = await ethers.deployContract("ReservedRMO");

      await expect(
        reservedRMO.connect(FIRST).upgradeToAndCall(await newReservedRMOImpl.getAddress(), "0x"),
      ).to.be.revertedWithCustomError(reservedRMO, "OwnableUnauthorizedAccount");
    });
  });

  describe("#pause", () => {
    it("should pause the contract", async () => {
      await reservedRMO.unpause();

      expect(await reservedRMO.paused()).to.be.false;

      const tx = await reservedRMO.pause();

      expect(await reservedRMO.paused()).to.be.true;
      await expect(tx).to.emit(reservedRMO, "Paused").withArgs(OWNER);
    });

    it("should get exception if not called by owner", async () => {
      await expect(reservedRMO.connect(FIRST).pause()).to.be.revertedWithCustomError(
        reservedRMO,
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("#unpause", () => {
    it("should unpause the contract", async () => {
      expect(await reservedRMO.paused()).to.be.true;

      const tx = await reservedRMO.unpause();

      expect(await reservedRMO.paused()).to.be.false;
      await expect(tx).to.emit(reservedRMO, "Unpaused").withArgs(OWNER);
    });

    it("should get exception if not called by owner", async () => {
      await expect(reservedRMO.connect(FIRST).unpause()).to.be.revertedWithCustomError(
        reservedRMO,
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("#setRMOToken", () => {
    it("should correctly set RMO token address", async () => {
      const tx = await reservedRMO.setRMOToken(RMO_TOKEN);

      expect(await reservedRMO.getRMOToken()).to.equal(await RMO_TOKEN.getAddress());
      await expect(tx)
        .to.emit(reservedRMO, "RMOTokenSet")
        .withArgs(await RMO_TOKEN.getAddress());
    });

    it("should get exception if try to set RMO token twice", async () => {
      await reservedRMO.setRMOToken(RMO_TOKEN);

      await expect(reservedRMO.setRMOToken(RMO_TOKEN)).to.be.revertedWithCustomError(reservedRMO, "RMOTokenAlreadySet");
    });

    it("should get exception if not called by owner", async () => {
      await expect(reservedRMO.connect(FIRST).setRMOToken(FIRST)).to.be.revertedWithCustomError(
        reservedRMO,
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("#setReservedTokensPerAddress", () => {
    it("should correctly set reserved tokens amount per address", async () => {
      const newReservedTokensAmount = wei(20000);
      const tx = await reservedRMO.setReservedTokensPerAddress(newReservedTokensAmount);

      expect(await reservedRMO.getReservedTokensPerAddress()).to.equal(newReservedTokensAmount);
      await expect(tx).to.emit(reservedRMO, "ReservedTokensPerAddressUpdated").withArgs(newReservedTokensAmount);
    });

    it("should get exception if try to set reserved tokens amount per address to zero", async () => {
      await expect(reservedRMO.setReservedTokensPerAddress(0)).to.be.revertedWithCustomError(
        reservedRMO,
        "ZeroReservedTokensAmountPerAddress",
      );
    });

    it("should get exception if not called by owner", async () => {
      await expect(reservedRMO.connect(FIRST).setReservedTokensPerAddress(wei(1))).to.be.revertedWithCustomError(
        reservedRMO,
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("#mintReservedTokens", () => {
    it("should mint reserved tokens for a vault address", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      expect(await reservedRMO.getMintedAmount(FIRST)).to.equal(0);
      const tx = await reservedRMO.mintReservedTokens(FIRST);

      expect(await reservedRMO.getMintedAmount(FIRST)).to.equal(reservedTokensAmountPerAddress);
      expect(await reservedRMO.balanceOf(FIRST)).to.equal(reservedTokensAmountPerAddress);
      expect(await reservedRMO.totalSupply()).to.equal(reservedTokensAmountPerAddress);

      await expect(tx)
        .to.emit(reservedRMO, "Transfer")
        .withArgs(ethers.ZeroAddress, FIRST, reservedTokensAmountPerAddress);
    });

    it("should get exception if try to mint tokens for the same vault again", async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      await reservedRMO.mintReservedTokens(FIRST);

      await expect(reservedRMO.mintReservedTokens(FIRST))
        .to.be.revertedWithCustomError(reservedRMO, "TokensAlreadyMintedForThisVault")
        .withArgs(await FIRST.getAddress());
    });

    it("should get exception if pass not a vault address", async () => {
      await expect(reservedRMO.mintReservedTokens(FIRST))
        .to.be.revertedWithCustomError(reservedRMO, "NotAVault")
        .withArgs(await FIRST.getAddress());
    });
  });

  describe("#burnReservedTokens", () => {
    beforeEach(async () => {
      await vaultFactory.setDeployedVault(FIRST, true);

      await reservedRMO.setRMOToken(RMO_TOKEN);
      await reservedRMO.mintReservedTokens(FIRST);
    });

    it("should burn reserved tokens from an account", async () => {
      expect(await reservedRMO.balanceOf(FIRST)).to.equal(reservedTokensAmountPerAddress);

      const tokensToBurn = reservedTokensAmountPerAddress / 2n;
      const tx = await reservedRMO.connect(RMO_TOKEN).burnReservedTokens(FIRST, tokensToBurn);

      expect(await reservedRMO.balanceOf(FIRST)).to.equal(reservedTokensAmountPerAddress - tokensToBurn);
      expect(await reservedRMO.totalSupply()).to.equal(reservedTokensAmountPerAddress - tokensToBurn);

      await expect(tx).to.emit(reservedRMO, "Transfer").withArgs(FIRST, ethers.ZeroAddress, tokensToBurn);
    });

    it("should get exception if not called by RMO token contract", async () => {
      await expect(reservedRMO.connect(FIRST).burnReservedTokens(FIRST, reservedTokensAmountPerAddress))
        .to.be.revertedWithCustomError(reservedRMO, "NotRMOToken")
        .withArgs(await FIRST.getAddress());
    });
  });

  describe("#transfer", () => {
    beforeEach(async () => {
      await vaultFactory.setDeployedVault(FIRST, true);
      await reservedRMO.mintReservedTokens(FIRST);
    });

    it("should transfer reserved tokens between accounts when not paused", async () => {
      await reservedRMO.unpause();

      expect(await reservedRMO.balanceOf(FIRST)).to.equal(reservedTokensAmountPerAddress);
      expect(await reservedRMO.balanceOf(SECOND)).to.equal(0);

      const tx = await reservedRMO.connect(FIRST).transfer(SECOND, reservedTokensAmountPerAddress);

      await expect(tx).to.changeTokenBalances(
        reservedRMO,
        [FIRST, SECOND],
        [-reservedTokensAmountPerAddress, reservedTokensAmountPerAddress],
      );

      await expect(tx).to.emit(reservedRMO, "Transfer").withArgs(FIRST, SECOND, reservedTokensAmountPerAddress);
    });

    it("should get exception if transfer is paused", async () => {
      expect(await reservedRMO.paused()).to.be.true;

      await expect(
        reservedRMO.connect(FIRST).transfer(SECOND, reservedTokensAmountPerAddress),
      ).to.be.revertedWithCustomError(reservedRMO, "EnforcedPause");
    });
  });

  describe("#transferFrom", () => {
    beforeEach(async () => {
      await vaultFactory.setDeployedVault(FIRST, true);
      await reservedRMO.mintReservedTokens(FIRST);

      await reservedRMO.connect(FIRST).approve(SECOND, reservedTokensAmountPerAddress);
    });

    it("should transfer reserved tokens between accounts when not paused", async () => {
      await reservedRMO.unpause();

      expect(await reservedRMO.balanceOf(FIRST)).to.equal(reservedTokensAmountPerAddress);
      expect(await reservedRMO.balanceOf(SECOND)).to.equal(0);

      const tx = await reservedRMO.connect(SECOND).transferFrom(FIRST, SECOND, reservedTokensAmountPerAddress);

      await expect(tx).to.changeTokenBalances(
        reservedRMO,
        [FIRST, SECOND],
        [-reservedTokensAmountPerAddress, reservedTokensAmountPerAddress],
      );

      await expect(tx).to.emit(reservedRMO, "Transfer").withArgs(FIRST, SECOND, reservedTokensAmountPerAddress);
    });

    it("should get exception if transfer is paused", async () => {
      expect(await reservedRMO.paused()).to.be.true;

      await expect(
        reservedRMO.connect(SECOND).transferFrom(FIRST, SECOND, reservedTokensAmountPerAddress),
      ).to.be.revertedWithCustomError(reservedRMO, "EnforcedPause");
    });
  });
});
