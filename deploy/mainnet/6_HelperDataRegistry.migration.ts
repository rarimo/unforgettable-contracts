import { HelperDataRegistry__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const helperDataRegistry = await deployer.deploy(HelperDataRegistry__factory);

  Reporter.reportContracts(["HelperDataRegistry", await helperDataRegistry.getAddress()]);
};
