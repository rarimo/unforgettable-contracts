import { SignatureSubscriptionModuleMock } from "@ethers-v6";
import { Reverter } from "@test-helpers";
import { getBuySubscriptionSignature } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("SignatureSubscriptionModule", () => {
  const reverter = new Reverter();

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SUBSCRIPTION_SIGNER: SignerWithAddress;

  let sigSubscriptionModule: SignatureSubscriptionModuleMock;

  beforeEach(async () => {
    [OWNER, FIRST, SUBSCRIPTION_SIGNER] = await ethers.getSigners();

    sigSubscriptionModule = await ethers.deployContract("SignatureSubscriptionModuleMock");

    await sigSubscriptionModule.initialize({ subscriptionSigner: SUBSCRIPTION_SIGNER });

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await sigSubscriptionModule.getSubscriptionSigner()).to.be.eq(SUBSCRIPTION_SIGNER);

      const domain = await sigSubscriptionModule.eip712Domain();
      expect(domain.name).to.be.eq("SignatureSubscriptionModule");
      expect(domain.version).to.be.eq("v1.0.0");
      expect(domain.verifyingContract).to.be.eq(await sigSubscriptionModule.getAddress());
    });

    it("should get exception if try to call init function directly", async () => {
      await expect(
        sigSubscriptionModule.__SignatureSubscriptionModule_init({ subscriptionSigner: FIRST }),
      ).to.be.revertedWithCustomError(sigSubscriptionModule, "NotInitializing");
    });
  });

  describe("#setSubscriptionSigner", () => {
    it("should correctly set subscription signer", async () => {
      const tx = await sigSubscriptionModule.setSubscriptionSigner(FIRST);

      expect(await sigSubscriptionModule.getSubscriptionSigner()).to.be.eq(FIRST);

      await expect(tx).to.emit(sigSubscriptionModule, "SubscriptionSignerUpdated").withArgs(FIRST.address);
    });

    it("should get exception if pass zero address", async () => {
      await expect(sigSubscriptionModule.setSubscriptionSigner(ethers.ZeroAddress))
        .to.be.revertedWithCustomError(sigSubscriptionModule, "ZeroAddr")
        .withArgs("SubscriptionSigner");
    });
  });

  describe("#buySubscriptionWithSignature", () => {
    it("should correctly buy subscription with signature", async () => {
      const duration = 3000n;
      const nonce = await sigSubscriptionModule.nonces(FIRST);

      const sig = await getBuySubscriptionSignature(sigSubscriptionModule, SUBSCRIPTION_SIGNER, {
        sender: FIRST.address,
        duration: duration,
        nonce: nonce,
      });

      const startTime = BigInt((await time.latest()) + 100);
      const expectedEndTime = startTime + duration;

      await time.setNextBlockTimestamp(startTime);
      const tx = await sigSubscriptionModule.connect(FIRST).buySubscriptionWithSignature(OWNER, duration, sig);

      expect(await sigSubscriptionModule.nonces(FIRST)).to.be.eq(nonce + 1n);

      await expect(tx)
        .to.emit(sigSubscriptionModule, "SubscriptionExtended")
        .withArgs(OWNER.address, duration, expectedEndTime);
      await expect(tx)
        .to.emit(sigSubscriptionModule, "SubscriptionBoughtWithSignature")
        .withArgs(FIRST.address, duration, nonce);

      expect(await sigSubscriptionModule.getSubscriptionStartTime(OWNER)).to.be.eq(startTime);
      expect(await sigSubscriptionModule.getSubscriptionEndTime(OWNER)).to.be.eq(expectedEndTime);

      expect(await sigSubscriptionModule.hasSubscription(OWNER)).to.be.true;
      expect(await sigSubscriptionModule.hasActiveSubscription(OWNER)).to.be.true;
    });

    it("should get exception if pass invalid signature", async () => {
      const duration = 3000n;
      const nonce = await sigSubscriptionModule.nonces(FIRST);

      const sig = await getBuySubscriptionSignature(sigSubscriptionModule, SUBSCRIPTION_SIGNER, {
        sender: FIRST.address,
        duration: duration,
        nonce: nonce,
      });

      await expect(
        sigSubscriptionModule.buySubscriptionWithSignature(OWNER, duration, sig),
      ).to.be.revertedWithCustomError(sigSubscriptionModule, "InvalidSignature");
    });
  });
});
