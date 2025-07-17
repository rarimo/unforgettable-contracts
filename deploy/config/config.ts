import hre, { ethers } from "hardhat";

import { DeployConfig } from "./types";

export async function getConfig(): Promise<DeployConfig> {
  if (hre.network.name == "localhost" || hre.network.name == "hardhat") {
    return validateConfig((await import("./localhost")).deployConfig);
  }

  if (hre.network.name == "sepolia") {
    return validateConfig((await import("./sepolia")).deployConfig);
  }

  throw new Error(`Config for network ${hre.network.name} is not specified`);
}

function validateConfig(config: DeployConfig): DeployConfig {
  if (!ethers.isAddress(config.contractsOwner)) {
    throw new Error("Invalid contracts address");
  }

  if (!ethers.isAddress(config.vaultsConfig.subscriptionSigner)) {
    throw new Error("Invalid vault subscription signer");
  }

  return config;
}
