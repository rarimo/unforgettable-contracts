import { VaultSubscriptionManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vaultSubscriptionManager = await deployer.deployERC1967Proxy(VaultSubscriptionManager__factory, "0x", {
    name: "VaultSubscriptionManager",
  });

  Reporter.reportContracts(["VaultSubscriptionManager", await vaultSubscriptionManager.getAddress()]);
};
