import { AccountSubscriptionManager__factory, RecoveryManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const subscriptionManager = await deployer.deployed(
    AccountSubscriptionManager__factory,
    "AccountSubscriptionManager proxy",
  );

  const recoveryManagerManagerInitData = RecoveryManager__factory.createInterface().encodeFunctionData(
    "initialize(address[],address[])",
    [[await subscriptionManager.getAddress()], []],
  );

  await deployer.deployERC1967Proxy(RecoveryManager__factory, recoveryManagerManagerInitData, {
    name: "RecoveryManager",
  });
};
