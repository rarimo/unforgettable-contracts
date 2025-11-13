import { HelperDataSubscriptionManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getHelperDataConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getHelperDataConfig();

  const helperDataSubscriptionManager = await deployer.deployERC1967Proxy(
    HelperDataSubscriptionManager__factory,
    "0x",
    {
      name: "HelperDataSubscriptionManager",
    },
  );

  await helperDataSubscriptionManager.initialize({
    subscriptionCreators: [],
    tokensPaymentInitData: config.helperDataSubscriptionManagerConfig.paymentTokenModuleConfig,
    sbtPaymentInitData: config.helperDataSubscriptionManagerConfig.sbtPaymentModuleConfig,
    sigSubscriptionInitData: config.helperDataSubscriptionManagerConfig.signatureSubscriptionModuleConfig,
    crossChainInitData: config.helperDataSubscriptionManagerConfig.crossChainModuleConfig,
  });

  Reporter.reportContracts(["HelperDataSubscriptionManager", await helperDataSubscriptionManager.getAddress()]);
};
