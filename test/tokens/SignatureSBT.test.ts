import { SignatureSBT } from "@ethers-v6";
import { Reverter, getMintSigSBTSignature } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("SignatureSBT", () => {
  const reverter = new Reverter();

  const name: string = "Test SBT";
  const symbol: string = "TSBT";

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let THIRD: SignerWithAddress;
  let SIGNER: SignerWithAddress;

  let sigSBTImpl: SignatureSBT;
  let sigSBT: SignatureSBT;

  function encodeTokenURI(tokenURI: string): string {
    return ethers.AbiCoder.defaultAbiCoder().encode(["string"], [tokenURI]);
  }

  beforeEach(async () => {
    [OWNER, FIRST, SECOND, THIRD, SIGNER] = await ethers.getSigners();

    sigSBTImpl = await ethers.deployContract("SignatureSBT");
    const sigSBTProxy = await ethers.deployContract("ERC1967Proxy", [await sigSBTImpl.getAddress(), "0x"]);

    sigSBT = await ethers.getContractAt("SignatureSBT", sigSBTProxy);

    await sigSBT.initialize(name, symbol);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#creation", () => {
    it("should set correct initial values", async () => {
      expect(await sigSBT.name()).to.equal(name);
      expect(await sigSBT.symbol()).to.equal(symbol);
      expect(await sigSBT.getOwners()).to.deep.equal([OWNER.address]);
    });

    it("should get exception when trying to call initialize again", async () => {
      await expect(sigSBT.initialize(name, symbol)).to.be.revertedWithCustomError(sigSBT, "InvalidInitialization");
    });
  });

  describe("#upgrade", () => {
    it("should upgrade the contract", async () => {
      const newSigSBTImpl = await ethers.deployContract("SignatureSBT");
      const tx = await sigSBT.upgradeToAndCall(await newSigSBTImpl.getAddress(), "0x");

      expect(await sigSBT.implementation()).to.equal(await newSigSBTImpl.getAddress());
      await expect(tx)
        .to.emit(sigSBT, "Upgraded")
        .withArgs(await newSigSBTImpl.getAddress());
    });

    it("should get exception if not called by owner", async () => {
      const newSigSBTImpl = await ethers.deployContract("SignatureSBT");

      await expect(sigSBT.connect(FIRST).upgradeToAndCall(await newSigSBTImpl.getAddress(), "0x"))
        .to.be.revertedWithCustomError(sigSBT, "UnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("addSigners", () => {
    it("should correctly add signers", async () => {
      const tx = await sigSBT.addSigners([FIRST, SECOND]);

      expect(await sigSBT.getSigners()).to.be.deep.eq([FIRST.address, SECOND.address]);
      expect(await sigSBT.isSigner(FIRST)).to.be.true;
      expect(await sigSBT.isSigner(SECOND)).to.be.true;

      await expect(tx).to.emit(sigSBT, "SignerAdded").withArgs(FIRST.address);
      await expect(tx).to.emit(sigSBT, "SignerAdded").withArgs(SECOND.address);
    });

    it("should get exception if tre to add already existing signer", async () => {
      await expect(sigSBT.addSigners([FIRST, FIRST]))
        .to.be.revertedWithCustomError(sigSBT, "SignerAlreadyAdded")
        .withArgs(FIRST.address);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(sigSBT.connect(FIRST).addSigners([FIRST]))
        .to.be.revertedWithCustomError(sigSBT, "UnauthorizedAccount")
        .withArgs(FIRST.address);
    });
  });

  describe("removeSigners", () => {
    beforeEach("setup", async () => {
      await sigSBT.addSigners([FIRST, SECOND, THIRD]);
    });

    it("should correctly remove signer", async () => {
      const tx = await sigSBT.removeSigners([FIRST]);

      expect(await sigSBT.getSigners()).to.be.deep.eq([THIRD.address, SECOND.address]);
      expect(await sigSBT.isSigner(FIRST)).to.be.false;

      await expect(tx).to.emit(sigSBT, "SignerRemoved").withArgs(FIRST.address);
    });

    it("should get exception if tre to remove non existing signer", async () => {
      await expect(sigSBT.removeSigners([OWNER]))
        .to.be.revertedWithCustomError(sigSBT, "NotASigner")
        .withArgs(OWNER.address);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(sigSBT.connect(SECOND).removeSigners([FIRST]))
        .to.be.revertedWithCustomError(sigSBT, "UnauthorizedAccount")
        .withArgs(SECOND.address);
    });
  });

  describe("mintSBT", () => {
    beforeEach("setup", async () => {
      await sigSBT.addSigners([SIGNER]);
    });

    it("should correctly mint SBT with signature", async () => {
      const tokenId = 123n;
      const tokenURI = "some URI";

      const sig = await getMintSigSBTSignature(sigSBT, SIGNER, {
        recipient: FIRST.address,
        tokenId: tokenId,
        tokenURI: encodeTokenURI(tokenURI),
      });

      const tx = await sigSBT.mintSBT(FIRST, tokenId, tokenURI, sig);

      expect(await sigSBT.balanceOf(FIRST)).to.be.eq(1);
      expect(await sigSBT.ownerOf(tokenId)).to.be.eq(FIRST);
      expect(await sigSBT.tokensOf(FIRST)).to.be.deep.eq([tokenId]);
      expect(await sigSBT.tokenURI(tokenId)).to.be.eq(tokenURI);

      await expect(tx).to.emit(sigSBT, "SBTMinted").withArgs(FIRST.address, tokenId, tokenURI);
    });

    it("should get exception if signer is not in the whitelist", async () => {
      const tokenId = 123n;
      const tokenURI = "some URI";

      const sig = await getMintSigSBTSignature(sigSBT, FIRST, {
        recipient: FIRST.address,
        tokenId: tokenId,
        tokenURI: encodeTokenURI(tokenURI),
      });

      await expect(sigSBT.mintSBT(FIRST, tokenId, tokenURI, sig))
        .to.be.revertedWithCustomError(sigSBT, "NotASigner")
        .withArgs(FIRST.address);
    });

    it("should get exception if pass invalid signature", async () => {
      const tokenId = 123n;
      const tokenURI = "some URI";

      const sig = await getMintSigSBTSignature(sigSBT, FIRST, {
        recipient: FIRST.address,
        tokenId: tokenId,
        tokenURI: encodeTokenURI(tokenURI),
      });

      await expect(
        sigSBT.mintSBT(FIRST, tokenId, tokenURI, sig.slice(0, sig.length - 8)),
      ).to.be.revertedWithCustomError(sigSBT, "InvalidSignature");
    });
  });
});
