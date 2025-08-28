import { getRecoverAccountSignature, getSafeTransactionSignature } from "@/test/helpers/sign-utils";
import {
  AccountSubscriptionManager,
  ERC20Mock,
  RecoveryManager,
  SafeMock,
  SignatureRecoveryStrategy,
  UnforgettableRecoveryModule,
} from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("UnforgettableRecoveryModule", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePaymentPeriod = 3600n * 24n * 30n;

  const paymentTokenSubscriptionCost = wei(5);

  const sentinel = "0x0000000000000000000000000000000000000001";

  let OWNER: SignerWithAddress;
  let FIRST: SignerWithAddress;
  let SECOND: SignerWithAddress;
  let THIRD: SignerWithAddress;
  let MASTER_KEY1: SignerWithAddress;
  let MASTER_KEY2: SignerWithAddress;
  let MASTER_KEY3: SignerWithAddress;

  let subscriptionManagerImpl: AccountSubscriptionManager;
  let subscriptionManager: AccountSubscriptionManager;

  let recoveryManager: RecoveryManager;
  let recoveryStrategy: SignatureRecoveryStrategy;

  let paymentToken: ERC20Mock;

  let accountImpl: SafeMock;
  let account: SafeMock;
  let recoveryModule: UnforgettableRecoveryModule;

  async function executeSafeTx(to: string, data: string, operation: bigint = 0n) {
    const value = 0n;
    const safeTxGas = 0n;
    const baseGas = 0n;
    const gasPrice = 0n;
    const gasToken = ZeroAddress;
    const refundReceiver = ZeroAddress;
    const nonce = await account.nonce();

    const txData = {
      to,
      value,
      data,
      operation,
      safeTxGas,
      baseGas,
      gasPrice,
      gasToken,
      refundReceiver,
      nonce,
    };

    const sig1 = await getSafeTransactionSignature(account, FIRST, txData);
    const sig2 = await getSafeTransactionSignature(account, SECOND, txData);

    function split(sig: string) {
      const bytes = ethers.getBytes(sig);
      const r = ethers.hexlify(bytes.slice(0, 32));
      const s = ethers.hexlify(bytes.slice(32, 64));
      const v = ethers.hexlify(bytes.slice(64, 65));
      return { r, s, v };
    }

    const rec1 = ethers.recoverAddress(
      await account.getTransactionHash(
        to,
        value,
        data,
        operation,
        safeTxGas,
        baseGas,
        gasPrice,
        gasToken,
        refundReceiver,
        nonce,
      ),
      sig1,
    );
    const rec2 = ethers.recoverAddress(
      await account.getTransactionHash(
        to,
        value,
        data,
        operation,
        safeTxGas,
        baseGas,
        gasPrice,
        gasToken,
        refundReceiver,
        nonce,
      ),
      sig2,
    );

    const tuples = [
      { addr: rec1.toLowerCase(), ...split(sig1) },
      { addr: rec2.toLowerCase(), ...split(sig2) },
    ].sort((a, b) => (a.addr < b.addr ? -1 : 1));

    const signatures = ethers.concat(tuples.map((t) => ethers.concat([t.r, t.s, t.v])));

    return await account.execTransaction(
      to,
      value,
      data,
      operation,
      safeTxGas,
      baseGas,
      gasPrice,
      gasToken,
      refundReceiver,
      signatures,
    );
  }

  before(async () => {
    [OWNER, FIRST, SECOND, THIRD, MASTER_KEY1, MASTER_KEY2, MASTER_KEY3] = await ethers.getSigners();

    paymentToken = await ethers.deployContract("ERC20Mock", ["Test Token", "TT", 18]);

    const recoveryManagerImpl = await ethers.deployContract("RecoveryManager");
    const recoveryManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await recoveryManagerImpl.getAddress(),
      "0x",
    ]);

    recoveryManager = await ethers.getContractAt("RecoveryManager", await recoveryManagerProxy.getAddress());

    subscriptionManagerImpl = await ethers.deployContract("AccountSubscriptionManager");

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      "0x",
    ]);
    subscriptionManager = await ethers.getContractAt(
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);
    await subscriptionManager.initialize({
      subscriptionCreators: [await recoveryManager.getAddress()],
      tokensPaymentInitData: {
        basePaymentPeriod: basePaymentPeriod,
        durationFactorEntries: [],
        paymentTokenEntries: [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
      },
      sbtPaymentInitData: {
        sbtEntries: [],
      },
      sigSubscriptionInitData: {
        subscriptionSigner: OWNER,
      },
    });

    accountImpl = await ethers.deployContract("SafeMock");
    const accountProxy = await ethers.deployContract("ERC1967Proxy", [await accountImpl.getAddress(), "0x"]);
    account = await ethers.getContractAt("SafeMock", await accountProxy.getAddress());

    await account.setup([FIRST, SECOND, THIRD], 2, ZeroAddress, "0x", ZeroAddress, ZeroAddress, 0, ZeroAddress);

    recoveryModule = await ethers.deployContract("UnforgettableRecoveryModule");

    await paymentToken.mint(account, initialTokensAmount);

    await reverter.snapshot();
  });

  beforeEach(async () => {
    const enableModuleData = account.interface.encodeFunctionData("enableModule", [await recoveryModule.getAddress()]);

    await executeSafeTx(await account.getAddress(), enableModuleData);

    expect(await account.isModuleEnabled(await recoveryModule.getAddress())).to.be.true;

    const approveData = paymentToken.interface.encodeFunctionData("approve", [
      await recoveryManager.getAddress(),
      paymentTokenSubscriptionCost,
    ]);

    await executeSafeTx(await paymentToken.getAddress(), approveData);
  });

  afterEach(reverter.revert);

  describe("#addRecoveryProvider", () => {
    it("should add recovery provider correctly", async () => {
      const accountRecoveryData1 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);
      const accountRecoveryData3 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY3.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [
              [0n, accountRecoveryData1],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      let recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[FIRST.address, THIRD.address], subscribeData],
      );

      let addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      let tx = await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);

      await expect(tx)
        .to.emit(account, "RecoveryProviderAdded")
        .withArgs(await recoveryManager.getAddress());

      const newRecoveryManager = await ethers.deployContract("RecoveryManagerMock");

      subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [[0n, accountRecoveryData2]],
          ],
        ],
      );

      recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[SECOND.address], subscribeData],
      );

      addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await newRecoveryManager.getAddress(),
        recoveryData,
      ]);

      tx = await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);

      await expect(tx)
        .to.emit(account, "RecoveryProviderAdded")
        .withArgs(await newRecoveryManager.getAddress());

      expect(await recoveryModule.getRecoverableOwners(account, recoveryManager)).to.be.deep.eq([
        FIRST.address,
        THIRD.address,
      ]);

      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, FIRST)).to.be.eq(0);
      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, THIRD)).to.be.eq(1);

      expect(await recoveryModule.getRecoverableOwners(account, newRecoveryManager)).to.be.deep.eq([SECOND.address]);
      expect(await recoveryModule.getRecoveryMethodId(account, newRecoveryManager, SECOND)).to.be.eq(0);
    });

    it("should get exception if try to add recovery provider with inconsistent recovery methods length", async () => {
      const accountRecoveryData1 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [
              [0n, accountRecoveryData1],
              [0n, accountRecoveryData2],
            ],
          ],
        ],
      );

      const recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[FIRST.address, SECOND.address, THIRD.address], subscribeData],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      await expect(executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n)).to.be.revertedWithCustomError(
        recoveryModule,
        "InvalidRecoveryMethodsLength",
      );
    });

    it("should get exception if try to add recovery provider with invalid Safe owner", async () => {
      const accountRecoveryData = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [[0n, accountRecoveryData]],
          ],
        ],
      );

      const recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[OWNER.address], subscribeData],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      await expect(executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n))
        .to.be.revertedWithCustomError(recoveryModule, "NotASafeOwner")
        .withArgs(OWNER.address);
    });

    it("should get exception if try to add recovery provider without delegate call", async () => {
      await expect(recoveryModule.addRecoveryProvider(recoveryManager, "0x")).to.be.revertedWithCustomError(
        recoveryModule,
        "NotADelegateCall",
      );
    });
  });

  describe("#removeRecoveryProvider", () => {
    it("should remover recovery provider correctly", async () => {
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);
      const accountRecoveryData3 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY3.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [
              [0n, accountRecoveryData2],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      const recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[SECOND.address, THIRD.address], subscribeData],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);

      const removeProviderData = recoveryModule.interface.encodeFunctionData("removeRecoveryProvider", [
        await recoveryManager.getAddress(),
      ]);

      let tx = await executeSafeTx(await recoveryModule.getAddress(), removeProviderData, 1n);

      await expect(tx)
        .to.emit(account, "RecoveryProviderRemoved")
        .withArgs(await recoveryManager.getAddress());

      expect(await recoveryModule.getRecoverableOwners(account, recoveryManager)).to.be.deep.eq([]);
      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, SECOND)).to.be.eq(0);
      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, THIRD)).to.be.eq(0);
    });

    it("should get exception if try to remover recovery provider without delegate call", async () => {
      await expect(recoveryModule.removeRecoveryProvider(recoveryManager)).to.be.revertedWithCustomError(
        recoveryModule,
        "NotADelegateCall",
      );
    });
  });

  describe("#updateRecoveryProvider", () => {
    it("should update recovery provider correctly", async () => {
      const accountRecoveryData1 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);
      const accountRecoveryData3 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY3.address]);

      let subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [
              [0n, accountRecoveryData2],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      let recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[SECOND.address, THIRD.address], subscribeData],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      let tx = await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);

      await expect(tx)
        .to.emit(account, "RecoveryProviderAdded")
        .withArgs(await recoveryManager.getAddress());

      subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            ZeroAddress,
            0n,
            [
              [0n, accountRecoveryData1],
              [0n, accountRecoveryData2],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[FIRST.address, SECOND.address, THIRD.address], subscribeData],
      );

      const updateProviderData = recoveryModule.interface.encodeFunctionData("updateRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      tx = await executeSafeTx(await recoveryModule.getAddress(), updateProviderData, 1n);

      await expect(tx)
        .to.emit(account, "RecoveryProviderRemoved")
        .withArgs(await recoveryManager.getAddress());

      await expect(tx)
        .to.emit(account, "RecoveryProviderAdded")
        .withArgs(await recoveryManager.getAddress());

      expect(await recoveryModule.getRecoverableOwners(account, recoveryManager)).to.be.deep.eq([
        FIRST.address,
        SECOND.address,
        THIRD.address,
      ]);

      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, FIRST)).to.be.eq(0);
      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, SECOND)).to.be.eq(1);
      expect(await recoveryModule.getRecoveryMethodId(account, recoveryManager, THIRD)).to.be.eq(2);
    });

    it("should get exception if try to update recovery provider without delegate call", async () => {
      await expect(recoveryModule.updateRecoveryProvider(recoveryManager, "0x")).to.be.revertedWithCustomError(
        recoveryModule,
        "NotADelegateCall",
      );
    });
  });

  describe("recoverAccess", () => {
    beforeEach(async () => {
      const accountRecoveryData1 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);
      const accountRecoveryData3 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY3.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePaymentPeriod,
            [
              [0n, accountRecoveryData1],
              [0n, accountRecoveryData2],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      const recoveryData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes"],
        [[FIRST.address, SECOND.address, THIRD.address], subscribeData],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        recoveryData,
      ]);

      await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);
    });

    it("should swap owner correctly", async () => {
      let object = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "address"],
        [await account.getAddress(), FIRST.address, SECOND.address, OWNER.address],
      );

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY2, {
        account: await account.getAddress(),
        object: object,
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, SECOND.address, THIRD.address]);

      const tx = await recoveryModule.connect(THIRD).recoverAccess(object, recoveryManager, recoveryProof);

      await expect(tx).to.emit(account, "AccessRecovered").withArgs(object);

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, OWNER.address, THIRD.address]);

      object = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "address"],
        [await account.getAddress(), sentinel, FIRST.address, SECOND.address],
      );

      signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY3, {
        account: await account.getAddress(),
        object: object,
        nonce: 1n,
      });

      recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      await expect(
        recoveryModule.connect(FIRST).recoverAccess(object, recoveryManager, recoveryProof),
      ).to.be.revertedWithCustomError(recoveryModule, "RecoveryValidationFailed");

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, OWNER.address, THIRD.address]);
    });

    it("should get exception if pass incorrect swapOwners parameters", async () => {
      const object = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "address"],
        [await account.getAddress(), SECOND.address, FIRST.address, OWNER.address],
      );

      const signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        object: object,
        nonce: 0n,
      });

      const recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      await expect(
        recoveryModule.connect(THIRD).recoverAccess(object, recoveryManager, recoveryProof),
      ).to.be.revertedWithCustomError(recoveryModule, "SwapOwnerCallFailed");
    });

    it("should get exception if provide not registered provider to validateRecoveryFromAccount", async () => {
      const object = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "address"],
        [await account.getAddress(), FIRST.address, SECOND.address, OWNER.address],
      );

      const signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY2, {
        account: await account.getAddress(),
        object: object,
        nonce: 0n,
      });

      const recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      const validateRecoveryData = recoveryModule.interface.encodeFunctionData("validateRecoveryFromAccount", [
        object,
        FIRST.address,
        recoveryProof,
      ]);

      await expect(executeSafeTx(await recoveryModule.getAddress(), validateRecoveryData, 1n))
        .to.be.revertedWithCustomError(recoveryModule, "ProviderNotRegistered")
        .withArgs(FIRST.address);
    });

    it("should get exception if provide invalid old owner to validateRecoveryFromAccount", async () => {
      const object = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address", "address"],
        [await account.getAddress(), FIRST.address, OWNER.address, MASTER_KEY3.address],
      );

      const signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY1, {
        account: await account.getAddress(),
        object: object,
        nonce: 0n,
      });

      const recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      const validateRecoveryData = recoveryModule.interface.encodeFunctionData("validateRecoveryFromAccount", [
        object,
        await recoveryManager.getAddress(),
        recoveryProof,
      ]);

      await expect(executeSafeTx(await recoveryModule.getAddress(), validateRecoveryData, 1n))
        .to.be.revertedWithCustomError(recoveryModule, "InvalidOldOwner")
        .withArgs(OWNER.address);
    });

    it("should get exception if try to call validateRecoveryFromAccount without delegate call", async () => {
      await expect(
        recoveryModule.validateRecoveryFromAccount("0x", recoveryManager, "0x"),
      ).to.be.revertedWithCustomError(recoveryModule, "NotADelegateCall");
    });
  });
});
