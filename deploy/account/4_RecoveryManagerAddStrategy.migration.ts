import { RecoveryManager__factory, SignatureRecoveryStrategy__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const signatureRecoveryStrategy = await deployer.deployed(
    SignatureRecoveryStrategy__factory,
    "SignatureRecoveryStrategy proxy",
  );

  await recoveryManager.addRecoveryStrategies([await signatureRecoveryStrategy.getAddress()]);
};
