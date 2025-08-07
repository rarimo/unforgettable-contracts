import { ETHER_ADDR, wei } from "@/scripts";

import { DeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  vaultsConfig: {
    basePeriodDuration: 3600n * 24n * 30n,
    vaultNameRetentionPeriod: 3600n * 24n * 30n * 12n,
    subscriptionSigner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    paymentTokenConfigs: [
      {
        paymentToken: ETHER_ADDR,
        baseSubscriptionCost: wei(1, 16),
      },
    ],
    vaultPaymentTokenConfigs: [
      {
        paymentToken: ETHER_ADDR,
        baseVaultNameCost: wei(5, 15),
      },
    ],
    sbtTokenConfigs: [],
  },
  accountSubscriptionManagerConfig: {
    basePeriodDuration: 3600n * 24n * 30n,
    subscriptionSigner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    paymentTokenConfigs: [
      {
        paymentToken: ETHER_ADDR,
        baseSubscriptionCost: wei(1, 16),
      },
    ],
    sbtTokenConfigs: [],
  },
};
