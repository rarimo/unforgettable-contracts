import { AccountSubscriptionManager__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const accountSubscriptionManagerInitData = AccountSubscriptionManager__factory.createInterface().encodeFunctionData(
    "initialize(uint64,address,(address,uint256)[],(address,uint64)[])",
    [
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
