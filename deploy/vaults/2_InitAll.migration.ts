import {
  RecoveryManager__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
  Vault__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultImpl = await deployer.deployed(Vault__factory, "VaultImpl");
  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");
  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");
  const vaultSubscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );

  await vaultFactory.initialize(vaultImpl, vaultSubscriptionManager);
  await recoveryManager.initialize([vaultSubscriptionManager], []);
  await vaultSubscriptionManager.initialize({
    recoveryManager: await recoveryManager.getAddress(),
    vaultFactoryAddr: await vaultFactory.getAddress(),
    subscriptionSigner: config.vaultsConfig.subscriptionSigner,
    basePeriodDuration: config.vaultsConfig.basePeriodDuration,
    vaultNameRetentionPeriod: config.vaultsConfig.vaultNameRetentionPeriod,
    basePaymentTokenEntries: config.vaultsConfig.paymentTokenConfigs,
    vaultPaymentTokenEntries: config.vaultsConfig.vaultPaymentTokenConfigs,
    sbtTokenEntries: config.vaultsConfig.sbtTokenConfigs,
  });
};
