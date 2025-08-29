import {
  AccountSubscriptionManager__factory,
  RecoveryManager__factory,
  SignatureRecoveryStrategy__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const recoveryManager = await deployer.deployed(RecoveryManager__factory, "RecoveryManager proxy");

  const accountSubscriptionManager = await deployer.deployed(
    AccountSubscriptionManager__factory,
    "AccountSubscriptionManager proxy",
  );

  const signatureRecoveryStrategy = await deployer.deployed(
    SignatureRecoveryStrategy__factory,
    "SignatureRecoveryStrategy proxy",
  );

  await recoveryManager.initialize(
    [await accountSubscriptionManager.getAddress()],
    [await signatureRecoveryStrategy.getAddress()],
  );

  await accountSubscriptionManager.initialize({
    subscriptionCreators: [await recoveryManager.getAddress()],
    tokensPaymentInitData: config.accountSubscriptionManagerConfig.paymentTokenModuleConfig,
    sbtPaymentInitData: config.accountSubscriptionManagerConfig.sbtPaymentModuleConfig,
    sigSubscriptionInitData: config.accountSubscriptionManagerConfig.signatureSubscriptionModuleConfig,
  });
};
