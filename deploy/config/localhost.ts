import { ETHER_ADDR, PRECISION, wei } from "@/scripts";

import { DeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  reservedRMOConfig: {
    reservedTokensAmountPerAddress: wei(100, 18),
  },
  vaultSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 3600n * 24n * 30n,
      durationFactorEntries: [
        {
          duration: 3600n * 24n * 30n * 12n,
          factor: PRECISION * 95n,
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: wei(1, 16),
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    },
  },
  accountSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 3600n * 24n * 30n,
      durationFactorEntries: [
        {
          duration: 3600n * 24n * 30n * 12n,
          factor: PRECISION * 95n,
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: wei(1, 16),
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    },
  },
};
