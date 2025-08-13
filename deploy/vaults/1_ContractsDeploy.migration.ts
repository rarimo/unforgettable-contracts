import {
  RecoveryManager__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
  Vault__factory,
} from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vaultImpl = await deployer.deploy(Vault__factory, { name: "VaultImpl" });

  const vaultFactory = await deployer.deployERC1967Proxy(VaultFactory__factory, "0x", { name: "VaultFactory" });
  const recoveryManager = await deployer.deployERC1967Proxy(RecoveryManager__factory, "0x", {
    name: "RecoveryManager",
  });
  const vaultSubscriptionManager = await deployer.deployERC1967Proxy(VaultSubscriptionManager__factory, "0x", {
    name: "VaultSubscriptionManager",
  });

  Reporter.reportContracts(
    ["VaultImpl", await vaultImpl.getAddress()],
    ["VaultFactory", await vaultFactory.getAddress()],
    ["RecoveryManager", await recoveryManager.getAddress()],
    ["VaultSubscriptionManager", await vaultSubscriptionManager.getAddress()],
  );
};
