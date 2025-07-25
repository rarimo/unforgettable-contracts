import { VaultFactory__factory, VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");
  const subscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );

  await vaultFactory.secondStepInitialize(await subscriptionManager.getAddress());
  await subscriptionManager.secondStepInitialize(await vaultFactory.getAddress());
};
