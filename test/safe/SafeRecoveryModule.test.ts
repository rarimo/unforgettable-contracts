import { getRecoverAccountSignature, getSafeTransactionSignature } from "@/test/helpers/sign-utils";
import {
  AccountSubscriptionManager,
  ERC20Mock,
  RecoveryManager,
  Safe,
  SafeRecoveryModule,
  SignatureRecoveryStrategy,
} from "@ethers-v6";
import { wei } from "@scripts";
import { Reverter } from "@test-helpers";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

describe("SafeRecoveryModule", () => {
  const reverter = new Reverter();

  const initialTokensAmount = wei(10000);
  const basePeriodDuration = 3600n * 24n * 30n;

  const paymentTokenSubscriptionCost = wei(5);

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

  let accountImpl: Safe;
  let account: Safe;
  let recoveryModule: SafeRecoveryModule;

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

    await account.execTransaction(
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
    const subscriptionManagerInitData = subscriptionManagerImpl.interface.encodeFunctionData(
      "initialize(address,uint64,address,(address,uint256)[],(address,uint64)[])",
      [
        await recoveryManager.getAddress(),
        basePeriodDuration,
        OWNER.address,
        [
          {
            paymentToken: await paymentToken.getAddress(),
            baseSubscriptionCost: paymentTokenSubscriptionCost,
          },
        ],
        [],
      ],
    );

    const subscriptionManagerProxy = await ethers.deployContract("ERC1967Proxy", [
      await subscriptionManagerImpl.getAddress(),
      subscriptionManagerInitData,
    ]);
    subscriptionManager = await ethers.getContractAt(
      "AccountSubscriptionManager",
      await subscriptionManagerProxy.getAddress(),
    );

    recoveryStrategy = await ethers.deployContract("SignatureRecoveryStrategy");

    await recoveryStrategy.initialize(await recoveryManager.getAddress());
    await recoveryManager.initialize([await subscriptionManager.getAddress()], [await recoveryStrategy.getAddress()]);

    accountImpl = await ethers.deployContract("Safe");
    const accountProxy = await ethers.deployContract("ERC1967Proxy", [await accountImpl.getAddress(), "0x"]);
    account = await ethers.getContractAt("Safe", await accountProxy.getAddress());

    await account.setup([FIRST, SECOND, THIRD], 2, ZeroAddress, "0x", ZeroAddress, ZeroAddress, 0, ZeroAddress);

    recoveryModule = await ethers.deployContract("SafeRecoveryModule");

    await paymentToken.mint(FIRST, initialTokensAmount);
    await paymentToken.mint(SECOND, initialTokensAmount);

    await reverter.snapshot();
  });

  beforeEach(async () => {
    const enableModuleData = account.interface.encodeFunctionData("enableModule", [await recoveryModule.getAddress()]);

    await executeSafeTx(await account.getAddress(), enableModuleData);

    expect(await account.isModuleEnabled(await recoveryModule.getAddress())).to.be.true;
  });

  afterEach(reverter.revert);

  describe("recoverAccess", () => {
    it("should swap owner correctly", async () => {
      await paymentToken.connect(FIRST).transfer(account, paymentTokenSubscriptionCost);

      const approveData = paymentToken.interface.encodeFunctionData("approve", [
        await recoveryManager.getAddress(),
        paymentTokenSubscriptionCost,
      ]);

      await executeSafeTx(await paymentToken.getAddress(), approveData);

      const accountRecoveryData1 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY1.address]);
      const accountRecoveryData2 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY2.address]);
      const accountRecoveryData3 = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [MASTER_KEY3.address]);

      const subscribeData = ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address,address,uint64,tuple(uint256,bytes)[])"],
        [
          [
            await subscriptionManager.getAddress(),
            await paymentToken.getAddress(),
            basePeriodDuration,
            [
              [0n, accountRecoveryData1],
              [0n, accountRecoveryData2],
              [0n, accountRecoveryData3],
            ],
          ],
        ],
      );

      const addProviderData = recoveryModule.interface.encodeFunctionData("addRecoveryProvider", [
        await recoveryManager.getAddress(),
        subscribeData,
      ]);

      await executeSafeTx(await recoveryModule.getAddress(), addProviderData, 1n);

      let subject = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [await account.getAddress(), SECOND.address, OWNER.address],
      );

      let signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY2, {
        account: await account.getAddress(),
        objectHash: ethers.keccak256(subject),
        nonce: 0n,
      });

      let recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, SECOND.address, THIRD.address]);

      let tx = await recoveryModule.connect(THIRD).recoverAccess(subject, recoveryManager, recoveryProof);

      await expect(tx).to.emit(recoveryModule, "AccessRecovered").withArgs(subject);

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, OWNER.address, THIRD.address]);

      subject = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "address"],
        [await account.getAddress(), FIRST.address, SECOND.address],
      );

      signature = await getRecoverAccountSignature(recoveryStrategy, MASTER_KEY3, {
        account: await account.getAddress(),
        objectHash: ethers.keccak256(subject),
        nonce: 1n,
      });

      recoveryProof = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "bytes"],
        [await subscriptionManager.getAddress(), signature],
      );

      await expect(
        recoveryModule.connect(FIRST).recoverAccess(subject, recoveryManager, recoveryProof),
      ).to.be.revertedWithCustomError(recoveryModule, "RecoverCallFailed");

      expect(await account.getOwners()).to.be.deep.eq([FIRST.address, OWNER.address, THIRD.address]);
    });
  });
});
