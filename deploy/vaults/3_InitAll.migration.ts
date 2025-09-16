import {
  ICreateX__factory,
  VaultFactory__factory,
  VaultSubscriptionManager__factory,
  Vault__factory,
} from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

import { getVaultFactoryAddr } from "./helpers/helpers";

export = async (deployer: Deployer) => {
  const config = await getConfig();
  const createXDeployer = await deployer.deployed(ICreateX__factory, "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed");

  const signerAddr = await (await deployer.getSigner()).getAddress();
  const vaultFactoryProxyAddr = await getVaultFactoryAddr(createXDeployer, signerAddr);

  const vaultSubscriptionManager = await deployer.deployed(
    VaultSubscriptionManager__factory,
    "VaultSubscriptionManager proxy",
  );

  const vaultImpl = await deployer.deployed(Vault__factory);
  const vaultFactory = await deployer.deployed(VaultFactory__factory, vaultFactoryProxyAddr);

  await vaultSubscriptionManager.initialize({
    vaultFactoryAddr: await vaultFactory.getAddress(),
    subscriptionCreators: [],
    tokensPaymentInitData: config.vaultSubscriptionManagerConfig.paymentTokenModuleConfig,
    sbtPaymentInitData: config.vaultSubscriptionManagerConfig.sbtPaymentModuleConfig,
    sigSubscriptionInitData: config.vaultSubscriptionManagerConfig.signatureSubscriptionModuleConfig,
    crossChainInitData: config.vaultSubscriptionManagerConfig.crossChainModuleConfig,
  });

  await vaultFactory.initialize(await vaultImpl.getAddress(), await vaultSubscriptionManager.getAddress());
};
