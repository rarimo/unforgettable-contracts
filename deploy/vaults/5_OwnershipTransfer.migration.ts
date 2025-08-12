import { VaultFactory__factory, VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");
  const subscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );

  await vaultFactory.transferOwnership(config.contractsOwner);
  await subscriptionManager.transferOwnership(config.contractsOwner);
};
