import {
  RecoveryManager__factory,
  ReservedRMO__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");
  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");
  const subscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );
  const reservedRMO = await deployer.deployed(ReservedRMO__factory, "ReservedRMO proxy");

  await vaultFactory.transferOwnership(config.contractsOwner);
  await recoveryManager.transferOwnership(config.contractsOwner);
  await subscriptionManager.transferOwnership(config.contractsOwner);
  await reservedRMO.transferOwnership(config.contractsOwner);
};
