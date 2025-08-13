import { ReservedRMO__factory, VaultFactory__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultFactory = await deployer.deployed(VaultFactory__factory, "VaultFactory proxy");

  const reservedRMOInitData = ReservedRMO__factory.createInterface().encodeFunctionData("initialize(address,uint256)", [
    await vaultFactory.getAddress(),
    config.vaultsConfig.reservedTokensAmountPerAddress,
  ]);
  const reservedRMO = await deployer.deployERC1967Proxy(ReservedRMO__factory, reservedRMOInitData, {
    name: "ReservedRMO",
  });

  Reporter.reportContracts(["ReservedRMO", await reservedRMO.getAddress()]);
};
