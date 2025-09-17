import { AccountSubscriptionManager__factory, RecoveryManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  if (config.contractsOwner !== (await (await deployer.getSigner()).getAddress())) {
    const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");
    const accountSubscriptionManager = await deployer.deployed(
      AccountSubscriptionManager__factory,
      "AccountSubscriptionManager proxy",
    );
    const sideChainSubscriptionManager = await deployer.deployed(
      AccountSubscriptionManager__factory,
      "SideChainSubscriptionManager proxy",
    );

    await recoveryManager.transferOwnership(config.contractsOwner);
    await accountSubscriptionManager.transferOwnership(config.contractsOwner);
    await sideChainSubscriptionManager.transferOwnership(config.contractsOwner);
  }
};
