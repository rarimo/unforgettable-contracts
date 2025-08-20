import {
  AccountSubscriptionManager__factory,
  RecoveryManager__factory,
  ReservedRMO__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  if (config.contractsOwner !== (await (await deployer.getSigner()).getAddress())) {
    const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");
    const vaultSubscriptionManager = await deployer.deployed(
      VaultSubscriptionManager__factory,
      "VaultSubscriptionManager proxy",
    );
    const accountSubscriptionManager = await deployer.deployed(
      AccountSubscriptionManager__factory,
      "AccountSubscriptionManager proxy",
    );
    const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");
    const reservedRMO = await deployer.deployed(ReservedRMO__factory, "ReservedRMO proxy");

    await vaultFactory.transferOwnership(config.contractsOwner);
    await recoveryManager.transferOwnership(config.contractsOwner);
    await vaultSubscriptionManager.transferOwnership(config.contractsOwner);
    await accountSubscriptionManager.transferOwnership(config.contractsOwner);
    await reservedRMO.transferOwnership(config.contractsOwner);
  }
};
