import { DeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "",
  vaultsConfig: {
    basePeriodDuration: 600n,
    vaultNameRetentionPeriod: 3600n,
    subscriptionSigner: "",
    paymentTokenConfigs: [
      {
        paymentToken: "0xbb2e698669534eaBa3e276F17802723371178581",
        baseSubscriptionCost: 5000000n,
        baseVaultNameCost: 1500000n,
      },
      {
        paymentToken: "0x91c6568751B94f559D84e4Cf83Eb6fC05fb9B9E8",
        baseSubscriptionCost: 3000000n,
        baseVaultNameCost: 1000000n,
      },
    ],
    sbtTokenConfigs: [
      {
        sbtToken: "0x0352Df2C21fB0A0405Dd3264e01913f6C51A0344",
        subscriptionTimePerToken: 3600n,
      },
    ],
  },
};
