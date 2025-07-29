import { VaultFactory__factory, Vault__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const vaultImpl = await deployer.deploy(Vault__factory, { name: "VaultImpl" });

  const vaultFactoryInitData = VaultFactory__factory.createInterface().encodeFunctionData("initialize(address)", [
    await vaultImpl.getAddress(),
  ]);

  await deployer.deployERC1967Proxy(VaultFactory__factory, vaultFactoryInitData, { name: "VaultFactory" });
};
