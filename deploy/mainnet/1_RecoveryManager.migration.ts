import { RecoveryManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  await getConfig();

  const recoveryManager = await deployer.deployERC1967Proxy(RecoveryManager__factory, "0x", {
    name: "RecoveryManager",
  });

  Reporter.reportContracts(["RecoveryManager", await recoveryManager.getAddress()]);
};
