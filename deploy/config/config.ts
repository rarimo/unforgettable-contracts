import hre, { ethers } from "hardhat";

import { DeployConfig, HelperDataDeployConfig } from "./types";

export async function getConfig(): Promise<DeployConfig> {
  if (hre.network.name == "localhost" || hre.network.name == "hardhat") {
    return validateConfig((await import("./localhost")).deployConfig);
  }

  if (hre.network.name == "sepolia") {
    return validateConfig((await import("./sepolia")).deployConfig);
  }

  if (hre.network.name == "ethereum") {
    return validateConfig((await import("./ethereum")).deployConfig);
  }

  throw new Error(`Config for network ${hre.network.name} is not specified`);
}

export async function getHelperDataConfig(): Promise<HelperDataDeployConfig> {
  if (hre.network.name == "localhost" || hre.network.name == "hardhat") {
    return validateHelperDataConfig((await import("./localhost")).helperDataDeployConfig);
  }

  if (hre.network.name == "sepolia") {
    return validateHelperDataConfig((await import("./sepolia")).helperDataDeployConfig);
  }

  if (hre.network.name == "ethereum") {
    return validateHelperDataConfig((await import("./ethereum")).helperDataDeployConfig);
  }

  throw new Error(`Config for network ${hre.network.name} is not specified`);
}

function validateConfig(config: DeployConfig): DeployConfig {
  if (!ethers.isAddress(config.contractsOwner)) {
    throw new Error("Invalid contracts address");
  }

  if (!ethers.isAddress(config.vaultSubscriptionManagerConfig.signatureSubscriptionModuleConfig.subscriptionSigner)) {
    throw new Error("Invalid vault subscription signer");
  }

  if (!ethers.isAddress(config.accountSubscriptionManagerConfig.signatureSubscriptionModuleConfig.subscriptionSigner)) {
    throw new Error("Invalid account subscription signer");
  }

  if (
    !ethers.isAddress(config.crosschainConfig.subscriptionsStateReceiverConfig.wormholeRelayer) ||
    !ethers.isAddress(config.crosschainConfig.subscriptionsSynchronizerConfig.wormholeRelayer)
  ) {
    throw new Error("Invalid wormhole relayer address");
  }

  return config;
}

function validateHelperDataConfig(config: HelperDataDeployConfig): HelperDataDeployConfig {
  config.helperDataFactoryConfig.helperDataManagers.forEach((manager: string) => {
    if (!ethers.isAddress(manager)) {
      throw new Error("Invalid helper data manager address");
    }
  });

  return config;
}
