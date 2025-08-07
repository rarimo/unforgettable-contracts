import { RecoveryManager__factory, VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const vaultSubscriptionManagerInitData = VaultSubscriptionManager__factory.createInterface().encodeFunctionData(
    "initialize(address,uint64,uint64,address,(address,uint256)[],(address,uint256)[],(address,uint64)[])",
    [
      await recoveryManager.getAddress(),
      config.vaultsConfig.basePeriodDuration,
      config.vaultsConfig.vaultNameRetentionPeriod,
      config.vaultsConfig.subscriptionSigner,
      config.vaultsConfig.paymentTokenConfigs,
      config.vaultsConfig.vaultPaymentTokenConfigs,
      config.vaultsConfig.sbtTokenConfigs,
    ],
  );

  await deployer.deployERC1967Proxy(VaultSubscriptionManager__factory, vaultSubscriptionManagerInitData, {
    name: "VaultSubscriptionManager",
  });
};
