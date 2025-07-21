import { HelperDataRegistry } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("HelperDataRegistry", () => {
  const reverter = new Reverter();

  let registry: HelperDataRegistry;

  let USER1: SignerWithAddress;
  let USER2: SignerWithAddress;

  const domain = {
    name: "HelperDataRegistry",
    version: "1",
    chainId: 0n,
    verifyingContract: ethers.ZeroAddress,
  };

  const types = {
    HelperData: [
      { name: "faceVersion", type: "uint256" },
      { name: "objectVersion", type: "uint256" },
      { name: "helperDataVersion", type: "uint256" },
      { name: "helperData", type: "bytes" },
    ],
  };

  before(async () => {
    [USER1, USER2] = await ethers.getSigners();

    registry = await ethers.deployContract("HelperDataRegistry");

    domain.chainId = (await ethers.provider.getNetwork()).chainId;
    domain.verifyingContract = await registry.getAddress();

    await registry.initialize();

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("initialize", () => {
    it("should not initialize the contract if it is already initialized", async () => {
      await expect(registry.initialize()).to.be.revertedWithCustomError(registry, "InvalidInitialization");
    });
  });

  describe("setHelperData", () => {
    it("should store helper data with a valid EIP-712 signature", async () => {
      const helperData1 = {
        faceVersion: 3,
        objectVersion: 4,
        helperDataVersion: 1,
        helperData: ethers.encodeBytes32String("data"),
      };

      const signature1 = await USER1.signTypedData(domain, types, helperData1);

      await registry.connect(USER1).setHelperData(helperData1, signature1);

      const helperData2 = {
        faceVersion: 1,
        objectVersion: 2,
        helperDataVersion: 2,
        helperData: ethers.encodeBytes32String("data2"),
      };

      const signature2 = await USER2.signTypedData(domain, types, helperData2);

      await registry.connect(USER2).setHelperData(helperData2, signature2);

      expect(await registry.getHelperData(USER1)).to.be.deep.equal([3, 4, 1, ethers.encodeBytes32String("data")]);
      expect(await registry.getHelperData(USER2)).to.be.deep.equal([1, 2, 2, ethers.encodeBytes32String("data2")]);
    });

    it("should not set helper data if it has been already set", async () => {
      const helperData1 = {
        faceVersion: 1,
        objectVersion: 2,
        helperDataVersion: 1,
        helperData: ethers.encodeBytes32String("data"),
      };

      let signature = await USER1.signTypedData(domain, types, helperData1);

      await registry.connect(USER1).setHelperData(helperData1, signature);

      const helperData2 = {
        faceVersion: 3,
        objectVersion: 2,
        helperDataVersion: 2,
        helperData: ethers.encodeBytes32String("new data"),
      };

      signature = await USER1.signTypedData(domain, types, helperData2);

      await expect(registry.connect(USER1).setHelperData(helperData2, signature))
        .to.be.revertedWithCustomError(registry, "HelperDataAlreadySet")
        .withArgs(USER1.address);

      expect(await registry.getHelperData(USER1)).to.be.deep.equal([1, 2, 1, ethers.encodeBytes32String("data")]);
    });

    it("should not set helper data with invalid EIP-712 signature", async () => {
      const helperData = {
        faceVersion: 3,
        objectVersion: 4,
        helperDataVersion: 1,
        helperData: ethers.encodeBytes32String("data"),
      };

      await expect(
        registry.connect(USER1).setHelperData(helperData, "0x" + "00".repeat(65)),
      ).to.be.revertedWithCustomError(registry, "ECDSAInvalidSignature");
    });
  });
});
