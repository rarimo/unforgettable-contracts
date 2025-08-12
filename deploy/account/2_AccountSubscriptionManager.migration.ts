import { AccountSubscriptionManager__factory, RecoveryManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const accountSubscriptionManagerInitData = AccountSubscriptionManager__factory.createInterface().encodeFunctionData(
    "initialize(address,uint64,address,(address,uint256)[],(address,uint64)[])",
    [
      await recoveryManager.getAddress(),
      config.accountSubscriptionManagerConfig.basePeriodDuration,
      config.accountSubscriptionManagerConfig.subscriptionSigner,
      config.accountSubscriptionManagerConfig.paymentTokenConfigs,
      config.accountSubscriptionManagerConfig.sbtTokenConfigs,
    ],
  );

  await deployer.deployERC1967Proxy(AccountSubscriptionManager__factory, accountSubscriptionManagerInitData, {
    name: "AccountSubscriptionManager",
  });
};
