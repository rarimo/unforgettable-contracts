import { VaultFactory__factory, Vault__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vault = await deployer.deploy(Vault__factory);

  const vaultFactory = await deployer.deployERC1967Proxy(VaultFactory__factory, "0x", { name: "VaultFactory" });

  Reporter.reportContracts(["Vault", await vault.getAddress()], ["VaultFactory", await vaultFactory.getAddress()]);
};
