import { ETHER_ADDR, PRECISION, wei } from "@scripts";

import { DeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "",
  reservedRMOConfig: {
    reservedTokensAmountPerAddress: wei(100, 18),
  },
  vaultSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 600n,
      durationFactorEntries: [
        {
          duration: 600n * 6n,
          factor: PRECISION * 95n,
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: wei(5, 11),
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "",
    },
  },
  accountSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 600n,
      durationFactorEntries: [
        {
          duration: 600n * 6n,
          factor: PRECISION * 95n,
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR,
          baseSubscriptionCost: wei(5, 11),
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [
        {
          sbt: "0x0352Df2C21fB0A0405Dd3264e01913f6C51A0344",
          subscriptionDurationPerToken: 3600n,
        },
      ],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "",
    },
  },
};
