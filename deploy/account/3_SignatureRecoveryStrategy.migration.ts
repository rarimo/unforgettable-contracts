import { RecoveryManager__factory, SignatureRecoveryStrategy__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const signatureRecoveryStrategyInitData = SignatureRecoveryStrategy__factory.createInterface().encodeFunctionData(
    "initialize(address)",
    [await recoveryManager.getAddress()],
  );

  await deployer.deployERC1967Proxy(SignatureRecoveryStrategy__factory, signatureRecoveryStrategyInitData, {
    name: "SignatureRecoveryStrategy",
  });
};
