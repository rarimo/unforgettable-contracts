import { ReservedRMO__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const vaultFactoryAddr = "0x";

  const reservedRMOInitData = ReservedRMO__factory.createInterface().encodeFunctionData("initialize(address,uint256)", [
    vaultFactoryAddr,
    config.reservedRMOConfig.reservedTokensAmountPerAddress,
  ]);
  const reservedRMO = await deployer.deployERC1967Proxy(ReservedRMO__factory, reservedRMOInitData, {
    name: "ReservedRMO",
  });

  await reservedRMO.transferOwnership(config.contractsOwner);

  Reporter.reportContracts(["ReservedRMO", await reservedRMO.getAddress()]);
};
