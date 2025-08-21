import { AccountSubscriptionManager__factory, VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vaultSubscriptionManager = await deployer.deployERC1967Proxy(VaultSubscriptionManager__factory, "0x", {
    name: "VaultSubscriptionManager",
  });
  const accountSubscriptionManager = await deployer.deployERC1967Proxy(AccountSubscriptionManager__factory, "0x", {
    name: "AccountSubscriptionManager",
  });

  Reporter.reportContracts(
    ["VaultSubscriptionManager", await vaultSubscriptionManager.getAddress()],
    ["AccountSubscriptionManager", await accountSubscriptionManager.getAddress()],
  );
};
