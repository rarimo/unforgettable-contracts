import { HelperDataFactory } from "@ethers-v6";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";

describe("HelperDataFactory", () => {
  const reverter = new Reverter();

  let factoryImpl: HelperDataFactory;
  let factory: HelperDataFactory;

  let OWNER: SignerWithAddress;
  let USER1: SignerWithAddress;
  let USER2: SignerWithAddress;
  let MANAGER: SignerWithAddress;

  enum AccountStatus {
    NONE = 0,
    ACTIVE,
    EXPIRED,
  }

  function encodePointerData(account: SignerWithAddress, index: bigint, data: string): string {
    return ethers.AbiCoder.defaultAbiCoder().encode(["address", "uint256", "bytes"], [account.address, index, data]);
  }

  before(async () => {
    [OWNER, USER1, USER2, MANAGER] = await ethers.getSigners();

    factoryImpl = await ethers.deployContract("HelperDataFactory");
    const factoryProxy = await ethers.deployContract("ERC1967Proxy", [await factoryImpl.getAddress(), "0x"]);

    factory = await ethers.getContractAt("HelperDataFactory", factoryProxy);

    await factory.initialize([MANAGER]);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should set correct initial data", async () => {
      expect(await factory.owner()).to.be.eq(OWNER);
      expect(await factory.isHelperDataManager(MANAGER)).to.be.true;
    });

    it("should not initialize the contract if it is already initialized", async () => {
      await expect(factory.initialize([USER1])).to.be.revertedWithCustomError(factory, "InvalidInitialization");
    });

    it("should get exception if not a deployer try to initialize contract", async () => {
      const newFactoryProxy = await ethers.deployContract("ERC1967Proxy", [await factoryImpl.getAddress(), "0x"]);
      const newFactory = await ethers.getContractAt("HelperDataFactory", newFactoryProxy);

      await expect(newFactory.connect(USER1).initialize([USER1]))
        .to.be.revertedWithCustomError(newFactory, "OnlyDeployer")
        .withArgs(USER1.address);
    });
  });

  describe("#upgrade", () => {
    it("should correctly upgrade HelperDataFactory contract", async () => {
      const newFactoryImpl = await ethers.deployContract("HelperDataFactory");

      await factory.upgradeToAndCall(newFactoryImpl, "0x");

      expect(await factory.implementation()).to.be.eq(newFactoryImpl);
    });

    it("should get exception if not an owner try to upgrade HelperDataFactory", async () => {
      const newFactoryImpl = await ethers.deployContract("HelperDataFactory");

      await expect(factory.connect(USER1).upgradeToAndCall(newFactoryImpl, "0x"))
        .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount")
        .withArgs(USER1.address);
    });
  });

  describe("#addHelperDataManagers", () => {
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

  describe("#removeHelperDataManagers", () => {
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
      await expect(factory.connect(USER1).removeHelperDataManagers([MANAGER]))
        .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount")
        .withArgs(USER1.address);
    });
  });

  describe("#registerAccount", () => {
    const metadata = ethers.encodeBytes32String("Some metadata");
    const data = ethers.encodeBytes32String("Useful data");
    let endTime: bigint;

    beforeEach("setup", async () => {
      endTime = BigInt(await time.latest()) + 100000n;
    });

    it("should correctly register an account", async () => {
      const tx = await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);

      expect(await factory.isAccountRegistered(USER1)).to.be.true;
      expect(await factory.getAccountStatus(USER1)).to.be.eq(AccountStatus.ACTIVE);

      expect(await factory.getRegisteredAccountsCount()).to.be.eq(1n);
      expect(await factory.getRegisteredAccounts()).to.be.deep.eq([USER1.address]);
      expect(await factory.getHelperDataPartsCount(USER1)).to.be.eq(1n);

      const pointers = await factory.getHelperDataPointers(USER1);

      expect(await factory.readPointersData([...pointers])).to.be.deep.eq([encodePointerData(USER1, 0n, data)]);

      await expect(tx).to.emit(factory, "AccountRegistered").withArgs(USER1.address);
      await expect(tx).to.emit(factory, "AccountSubscriptionEndTimeUpdated").withArgs(USER1.address, endTime);
      await expect(tx).to.emit(factory, "AccountMetadataUpdated").withArgs(USER1.address, metadata);
    });

    it("should get exception if the account is already registered", async () => {
      await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);

      expect(await factory.isAccountRegistered(USER1)).to.be.true;

      await expect(factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data))
        .to.be.revertedWithCustomError(factory, "AccountAlreadyRegistered")
        .withArgs(USER1.address);
    });

    it("should get exception if not a helper data manager try to call this function", async () => {
      await expect(factory.connect(USER1).registerAccount(USER1, 0n, endTime, metadata, data))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(USER1.address);
    });
  });

  describe("#updateAccountMetadata", () => {
    const metadata = ethers.encodeBytes32String("Some metadata");
    const data = ethers.encodeBytes32String("Useful data");
    let endTime: bigint;

    beforeEach("setup", async () => {
      endTime = BigInt(await time.latest()) + 100000n;

      await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);
    });

    it("should correctly update account metadata", async () => {
      const newMetadata = ethers.encodeBytes32String("Some new metadata");

      const tx = await factory.connect(MANAGER).updateAccountMetadata(USER1, newMetadata);

      const info = await factory.getAccountInfo(USER1);

      expect(info.metadata).to.be.eq(newMetadata);

      await expect(tx).to.emit(factory, "AccountMetadataUpdated").withArgs(USER1.address, newMetadata);
    });

    it("should get exception if the account is not registered", async () => {
      const newMetadata = ethers.encodeBytes32String("Some new metadata");

      await expect(factory.connect(MANAGER).updateAccountMetadata(OWNER, newMetadata))
        .to.be.revertedWithCustomError(factory, "NotARegisteredAccount")
        .withArgs(OWNER.address);
    });

    it("should get exception if not a helper data manager try to call this function", async () => {
      const newMetadata = ethers.encodeBytes32String("Some new metadata");

      await expect(factory.connect(USER1).updateAccountMetadata(USER1, newMetadata))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(USER1.address);
    });
  });

  describe("#updateAccountSubscriptionEndTime", () => {
    const metadata = ethers.encodeBytes32String("Some metadata");
    const data = ethers.encodeBytes32String("Useful data");
    let endTime: bigint;

    beforeEach("setup", async () => {
      endTime = BigInt(await time.latest()) + 100000n;

      await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);
    });

    it("should correctly update account subscription end time", async () => {
      const newEndTime = BigInt(await time.latest()) + 200000n;

      const tx = await factory.connect(MANAGER).updateAccountSubscriptionEndTime(USER1, newEndTime);

      const info = await factory.getAccountInfo(USER1);

      expect(info.subscriptionEndTime).to.be.eq(newEndTime);

      await expect(tx).to.emit(factory, "AccountSubscriptionEndTimeUpdated").withArgs(USER1.address, newEndTime);
    });

    it("should get exception if the account is not registered", async () => {
      const newEndTime = BigInt(await time.latest()) + 200000n;

      await expect(factory.connect(MANAGER).updateAccountSubscriptionEndTime(OWNER, newEndTime))
        .to.be.revertedWithCustomError(factory, "NotARegisteredAccount")
        .withArgs(OWNER.address);
    });

    it("should get exception if not a helper data manager try to call this function", async () => {
      const newEndTime = BigInt(await time.latest()) + 200000n;

      await expect(factory.connect(USER1).updateAccountSubscriptionEndTime(USER1, newEndTime))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(USER1.address);
    });
  });

  describe("#increaseAccountSubscriptionEndTime", async () => {
    const metadata = ethers.encodeBytes32String("Some metadata");
    const data = ethers.encodeBytes32String("Useful data");
    let endTime: bigint;

    beforeEach("setup", async () => {
      endTime = BigInt(await time.latest()) + 100000n;

      await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);
    });

    it("should correctly increase account subscription end time", async () => {
      const newEndTimeDelta = 20000n;

      const tx = await factory.connect(MANAGER).increaseAccountSubscriptionEndTime(USER1, newEndTimeDelta);

      const info = await factory.getAccountInfo(USER1);
      const expectedEndTime = newEndTimeDelta + endTime;

      expect(info.subscriptionEndTime).to.be.eq(expectedEndTime);

      await expect(tx).to.emit(factory, "AccountSubscriptionEndTimeUpdated").withArgs(USER1.address, expectedEndTime);
    });

    it("should get exception if the account is not registered", async () => {
      const newEndTimeDelta = 20000n;

      await expect(factory.connect(MANAGER).increaseAccountSubscriptionEndTime(OWNER, newEndTimeDelta))
        .to.be.revertedWithCustomError(factory, "NotARegisteredAccount")
        .withArgs(OWNER.address);
    });

    it("should get exception if not a helper data manager try to call this function", async () => {
      const newEndTimeDelta = 20000n;

      await expect(factory.connect(USER1).increaseAccountSubscriptionEndTime(USER1, newEndTimeDelta))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(USER1.address);
    });
  });

  describe("#submitHelperDataPart", () => {
    const metadata = ethers.encodeBytes32String("Some metadata");
    const data = ethers.encodeBytes32String("Useful data");
    let endTime: bigint;

    beforeEach("setup", async () => {
      endTime = BigInt(await time.latest()) + 100000n;

      await factory.connect(MANAGER).registerAccount(USER1, 0n, endTime, metadata, data);
    });

    it("should correctly submit helper data part", async () => {
      const DATA_PART_2 = ethers.encodeBytes32String("Helper data part 2");
      const DATA_PART_3 = ethers.encodeBytes32String("Helper data part 3");
      let index = 1n;

      const pointerAddress1 = await factory.connect(MANAGER).submitHelperDataPart.staticCall(USER1, index, DATA_PART_2);
      let tx = await factory.connect(MANAGER).submitHelperDataPart(USER1, index, DATA_PART_2);

      await expect(tx).to.emit(factory, "HelperDataPartSubmitted").withArgs(USER1.address, index, pointerAddress1);

      expect(await factory.getRegisteredAccountsCount()).to.be.eq(1n);
      expect(await factory.getRegisteredAccounts()).to.deep.eq([USER1.address]);
      expect(await factory.getHelperDataPartsCount(USER1)).to.be.eq(2n);
      expect((await factory.getHelperDataPointers(USER1))[1]).to.be.eq(pointerAddress1);

      let expectedData = encodePointerData(USER1, index, DATA_PART_2);

      expect(await factory.readPointersData([pointerAddress1])).to.be.deep.eq([expectedData]);

      index = 2n;

      const pointerAddress2 = await factory.connect(MANAGER).submitHelperDataPart.staticCall(USER1, index, DATA_PART_3);
      tx = await factory.connect(MANAGER).submitHelperDataPart(USER1, index, DATA_PART_3);

      await expect(tx).to.emit(factory, "HelperDataPartSubmitted").withArgs(USER1.address, index, pointerAddress2);

      expect(await factory.getHelperDataPartsCount(USER1)).to.be.eq(3n);
      expect((await factory.getHelperDataPointers(USER1)).slice(1)).to.be.deep.eq([pointerAddress1, pointerAddress2]);

      expectedData = encodePointerData(USER1, index, DATA_PART_3);

      expect(await factory.readPointersData([pointerAddress2])).to.be.deep.eq([expectedData]);
    });

    it("should get exception if the helper data index is already set", async () => {
      await expect(factory.connect(MANAGER).submitHelperDataPart(USER1, 0n, data))
        .to.be.revertedWithCustomError(factory, "HelperDataIndexAlreadySet")
        .withArgs(USER1.address, 0n);
    });

    it("should get exception if the account is not registered", async () => {
      const DATA_PART = ethers.encodeBytes32String("Helper data part");
      const index = 0n;

      await expect(factory.connect(MANAGER).submitHelperDataPart(USER2, index, DATA_PART))
        .to.be.revertedWithCustomError(factory, "NotARegisteredAccount")
        .withArgs(USER2.address);
    });

    it("should get exception if not a helper data manager try to call this function", async () => {
      const DATA_PART_2 = ethers.encodeBytes32String("Helper data part 2");
      const index = 1n;

      await expect(factory.connect(USER1).submitHelperDataPart(USER1, index, DATA_PART_2))
        .to.be.revertedWithCustomError(factory, "NotAHelperDataManager")
        .withArgs(USER1.address);
    });
  });

  describe("#getRegisteredAccountsWithFilters", () => {
    let accounts: SignerWithAddress[];
    let endTimeArr: bigint[];

    beforeEach("setup", async () => {
      const currentTime = BigInt(await time.latest());
      const testData = ethers.encodeBytes32String("Test data");

      accounts = [OWNER, USER1, USER2];
      endTimeArr = [currentTime + 100n, currentTime + 200n, currentTime + 300n];

      for (let i = 0; i < accounts.length; i++) {
        await factory.connect(MANAGER).registerAccount(accounts[i], 0n, endTimeArr[i], ethers.ZeroHash, testData);
      }
    });

    it("should correctly filter registered accounts by status", async () => {
      let result = await factory.getRegisteredAccountsWithFilters(AccountStatus.ACTIVE, ethers.ZeroHash);
      let expectedAccounts = accounts.map((acc) => acc.address);

      expect(result).to.be.deep.eq(expectedAccounts);

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.NONE, ethers.ZeroHash);

      expect(result).to.be.deep.eq([]);

      await time.increaseTo(endTimeArr[0] + 10n);

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.ACTIVE, ethers.ZeroHash);

      expect(result).to.be.deep.eq(expectedAccounts.slice(1));

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.EXPIRED, ethers.ZeroHash);

      expect(result).to.be.deep.eq([expectedAccounts[0]]);

      await factory
        .connect(MANAGER)
        .registerAccount(MANAGER, 0n, 0n, ethers.ZeroHash, ethers.encodeBytes32String("data"));

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.NONE, ethers.ZeroHash);

      expect(result).to.be.deep.eq([MANAGER.address]);
    });

    it("should correctly filter registered accounts by status and metadata", async () => {
      const testMetadata = ethers.encodeBytes32String("Test metadata");
      let expectedAccounts = [USER1.address, USER2.address];

      await factory.connect(MANAGER).updateAccountMetadata(USER1, testMetadata);
      await factory.connect(MANAGER).updateAccountMetadata(USER2, testMetadata);

      let result = await factory.getRegisteredAccountsWithFilters(AccountStatus.ACTIVE, testMetadata);

      expect(result).to.be.deep.eq(expectedAccounts);

      await time.increaseTo(endTimeArr[1] + 10n);

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.ACTIVE, testMetadata);

      expect(result).to.be.deep.eq(expectedAccounts.slice(1));

      result = await factory.getRegisteredAccountsWithFilters(AccountStatus.EXPIRED, testMetadata);

      expect(result).to.be.deep.eq([expectedAccounts[0]]);
    });
  });
});
