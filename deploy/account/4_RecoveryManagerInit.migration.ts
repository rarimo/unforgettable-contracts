import {
  AccountSubscriptionManager__factory,
  RecoveryManager__factory,
  SignatureRecoveryStrategy__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const subscriptionManager = await deployer.deployed(
    AccountSubscriptionManager__factory,
    "AccountSubscriptionManager proxy",
  );
  const recoveryStrategy = await deployer.deployed(
    SignatureRecoveryStrategy__factory,
    "SignatureRecoveryStrategy proxy",
  );

  await recoveryManager.updateSubscriptionManagers([await subscriptionManager.getAddress()], true);
  await recoveryManager.addRecoveryStrategies([await recoveryStrategy.getAddress()]);
};
