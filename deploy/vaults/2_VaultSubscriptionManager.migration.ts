import { VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultSubscriptionManagerInitData = VaultSubscriptionManager__factory.createInterface().encodeFunctionData(
    "initialize(uint64,address,(address,uint256)[],(address,uint64)[])",
    [
      config.vaultsConfig.basePeriodDuration,
      config.vaultsConfig.subscriptionSigner,
      config.vaultsConfig.paymentTokenConfigs,
      config.vaultsConfig.sbtTokenConfigs,
    ],
  );

  await deployer.deployProxy(
    VaultSubscriptionManager__factory,
    "ERC1967Proxy",
    (implementationAddress: string): any[] => {
      return [implementationAddress, vaultSubscriptionManagerInitData];
    },
    {
      name: "VaultSubscriptionManager",
    },
  );
};
