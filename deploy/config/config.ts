import hre, { ethers } from "hardhat";

import { DeployConfig } from "./types";

export async function getConfig(): Promise<DeployConfig> {
  if (hre.network.name == "localhost" || hre.network.name == "hardhat") {
    return validateConfig((await import("./localhost")).deployConfig);
  }

  if (hre.network.name == "sepolia") {
    return validateConfig((await import("./sepolia")).deployConfig);
  }

  if (hre.network.name == "bscTest") {
    return validateConfig((await import("./bscTest")).deployConfig);
  }

  if (hre.network.name == "ethereum") {
    return validateConfig((await import("./ethereum")).deployConfig);
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

  return config;
}
