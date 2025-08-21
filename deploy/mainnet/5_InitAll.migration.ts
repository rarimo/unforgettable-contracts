import {
  AccountSubscriptionManager__factory,
  RecoveryManager__factory,
  SignatureRecoveryStrategy__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
  Vault__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const vaultSubscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );
  const accountSubscriptionManager = await deployer.deployed(
    AccountSubscriptionManager__factory,
    "AccountSubscriptionManager proxy",
  );

  const vaultImpl = await deployer.deployed(Vault__factory);
  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");

  const signatureRecoveryStrategy = await deployer.deployed(
    SignatureRecoveryStrategy__factory,
    "SignatureRecoveryStrategy proxy",
  );

  await recoveryManager.initialize(
    [await vaultSubscriptionManager.getAddress(), await accountSubscriptionManager.getAddress()],
    [await signatureRecoveryStrategy.getAddress()],
  );

  await vaultSubscriptionManager.initialize({
    vaultFactoryAddr: await vaultFactory.getAddress(),
    vaultNameRetentionPeriod: config.vaultSubscriptionManagerConfig.vaultNameRetentionPeriod,
    subscriptionCreators: [],
    vaultPaymentTokenEntries: config.vaultSubscriptionManagerConfig.vaultPaymentTokenEntries,
    tokensPaymentInitData: config.vaultSubscriptionManagerConfig.paymentTokenModuleConfig,
    sbtPaymentInitData: config.vaultSubscriptionManagerConfig.sbtPaymentModuleConfig,
    sigSubscriptionInitData: config.vaultSubscriptionManagerConfig.signatureSubscriptionModuleConfig,
  });

  await accountSubscriptionManager.initialize({
    subscriptionCreators: [await recoveryManager.getAddress()],
    tokensPaymentInitData: config.accountSubscriptionManagerConfig.paymentTokenModuleConfig,
    sbtPaymentInitData: config.accountSubscriptionManagerConfig.sbtPaymentModuleConfig,
    sigSubscriptionInitData: config.accountSubscriptionManagerConfig.signatureSubscriptionModuleConfig,
  });

  await vaultFactory.initialize(await vaultImpl.getAddress(), await vaultSubscriptionManager.getAddress());
};
