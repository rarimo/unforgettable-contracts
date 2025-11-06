import { HelperDataFactory } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe.only("HelperDataFactory", () => {
  const reverter = new Reverter();

  let factoryImpl: HelperDataFactory;
  let factory: HelperDataFactory;

  let OWNER: SignerWithAddress;
  let USER1: SignerWithAddress;
  let MANAGER: SignerWithAddress;

  before(async () => {
    [OWNER, USER1, MANAGER] = await ethers.getSigners();

    factoryImpl = await ethers.deployContract("HelperDataFactory");
    const factoryProxy = await ethers.deployContract("ERC1967Proxy", [await factoryImpl.getAddress(), "0x"]);

    factory = await ethers.getContractAt("HelperDataFactory", factoryProxy);

    await factory.initialize([MANAGER]);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("initialize", () => {
    it("should set correct initial data", async () => {
      expect(await factory.owner()).to.be.eq(OWNER);
      expect(await factory.isHelperDataManager(MANAGER)).to.be.true;
    });

    it("should not initialize the contract if it is already initialized", async () => {
      await expect(factory.initialize([USER1])).to.be.revertedWithCustomError(factory, "InvalidInitialization");
    });
  });

  describe("addHelperDataManagers", () => {
    it("should correctly add helper data managers", async () => {
      const tx = await factory.addHelperDataManagers([USER1]);

      expect(await factory.getHelperDataManagers()).to.be.deep.eq([MANAGER.address, USER1.address]);
      expect(await factory.isHelperDataManager(USER1)).to.be.true;

      await expect(tx).to.emit(factory, "HelperDataManagerAdded").withArgs(USER1.address);
    });

    it("should get exception if try to add existing manager", async () => {
      await expect(factory.addHelperDataManagers([MANAGER]))
        .to.be.revertedWithCustomError(factory, "HelperDataManagerAlreadyAdded")
        .withArgs(MANAGER.address);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(factory.connect(USER1).addHelperDataManagers([USER1]))
        .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount")
        .withArgs(USER1.address);
    });
  });

  describe("removeHelperDataManagers", () => {
    beforeEach("setup", async () => {
      await factory.addHelperDataManagers([USER1, OWNER]);
    });

    it("should correctly remove helper data managers", async () => {
      const tx = await factory.removeHelperDataManagers([MANAGER]);

      expect(await factory.getHelperDataManagers()).to.be.deep.eq([OWNER.address, USER1.address]);
      expect(await factory.isHelperDataManager(MANAGER)).to.be.false;

      await expect(tx).to.emit(factory, "HelperDataManagerRemoved").withArgs(MANAGER.address);
    });

    it("should get exception if try to remove non-existing manager", async () => {
      const NON_MANAGER = (await ethers.getSigners())[5];

      await expect(factory.removeHelperDataManagers([NON_MANAGER]))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(NON_MANAGER);
    });

    it("should get exception if not an owner try to call this function", async () => {
      await expect(factory.connect(USER1).addHelperDataManagers([MANAGER]))
        .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount")
        .withArgs(USER1.address);
    });
  });

  describe("submitHelperDataPart", () => {
    it("should correctly submit helper data part", async () => {
      const DATA_PART_1 = ethers.encodeBytes32String("Helper data part 1");
      const DATA_PART_2 = ethers.encodeBytes32String("Helper data part 2");
      const helperDataId = ethers.solidityPackedKeccak256(["bytes", "bytes"], [DATA_PART_1, DATA_PART_2]);
      let index = 0n;

      const pointerAddress1 = await factory
        .connect(MANAGER)
        .submitHelperDataPart.staticCall(helperDataId, index, DATA_PART_1);
      let tx = await factory.connect(MANAGER).submitHelperDataPart(helperDataId, index, DATA_PART_1);

      await expect(tx).to.emit(factory, "HelperDataPartSubmitted").withArgs(helperDataId, index, pointerAddress1);

      expect(await factory.getHelperDataIdsCount()).to.be.eq(1n);
      expect(await factory.getHelperDataIds()).to.deep.eq([helperDataId]);
      expect(await factory.getHelperDataPartsCount(helperDataId)).to.be.eq(1n);
      expect(await factory.getHelperDataPointers(helperDataId)).to.be.deep.eq([pointerAddress1]);

      let expectedData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["bytes32", "uint256", "bytes"],
        [helperDataId, index, DATA_PART_1],
      );

      expect(await factory.readPointersData([pointerAddress1])).to.be.deep.eq([expectedData]);

      index = 1n;

      const pointerAddress2 = await factory
        .connect(MANAGER)
        .submitHelperDataPart.staticCall(helperDataId, index, DATA_PART_2);
      tx = await factory.connect(MANAGER).submitHelperDataPart(helperDataId, index, DATA_PART_2);

      await expect(tx).to.emit(factory, "HelperDataPartSubmitted").withArgs(helperDataId, index, pointerAddress2);

      expect(await factory.getHelperDataIdsCount()).to.be.eq(1n);
      expect(await factory.getHelperDataIds()).to.deep.eq([helperDataId]);
      expect(await factory.getHelperDataPartsCount(helperDataId)).to.be.eq(2n);
      expect(await factory.getHelperDataPointers(helperDataId)).to.be.deep.eq([pointerAddress1, pointerAddress2]);

      expectedData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["bytes32", "uint256", "bytes"],
        [helperDataId, index, DATA_PART_2],
      );

      expect(await factory.readPointersData([pointerAddress2])).to.be.deep.eq([expectedData]);
    });
  });
});
