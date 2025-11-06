import { HelperDataFactory__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getHelperDataConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getHelperDataConfig();

  const helperDataFactoryInitData = HelperDataFactory__factory.createInterface().encodeFunctionData(
    "initialize(address[])",
    [config.helperDataFactoryConfig.helperDataManagers],
  );
  const helperDataFactory = await deployer.deployERC1967Proxy(HelperDataFactory__factory, helperDataFactoryInitData, {
    name: "HelperDataFactory",
  });

  Reporter.reportContracts(["HelperDataFactory", await helperDataFactory.getAddress()]);
};
