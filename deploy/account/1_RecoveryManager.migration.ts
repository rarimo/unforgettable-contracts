import { RecoveryManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const recoveryManagerManagerInitData = RecoveryManager__factory.createInterface().encodeFunctionData(
    "initialize(address[],address[])",
    [[], []],
  );

  await deployer.deployERC1967Proxy(RecoveryManager__factory, recoveryManagerManagerInitData, {
    name: "RecoveryManager",
  });
};
