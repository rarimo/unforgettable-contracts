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
      discountEntries: [],
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
        {
          paymentToken: "0xbb2e698669534eaBa3e276F17802723371178581",
          baseSubscriptionCost: 5000000n,
        },
        {
          paymentToken: "0x91c6568751B94f559D84e4Cf83Eb6fC05fb9B9E8",
          baseSubscriptionCost: 3000000n,
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
    crossChainModuleConfig: {
      subscriptionsSynchronizer: "0x0000000000000000000000000000000000000000",
    },
  },
  accountSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 600n,
      discountEntries: [],
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
        {
          paymentToken: "0xbb2e698669534eaBa3e276F17802723371178581",
          baseSubscriptionCost: 5000000n,
        },
        {
          paymentToken: "0x91c6568751B94f559D84e4Cf83Eb6fC05fb9B9E8",
          baseSubscriptionCost: 3000000n,
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
    crossChainModuleConfig: {
      subscriptionsSynchronizer: "0x000000000000000000000000000000000000000",
    },
  },
  sideChainSubscriptionManagerConfig: {
    baseSideChainSubscriptionManagerConfig: {
      subscriptionsStateReceiver: "0x0000000000000000000000000000000000000000",
      sourceSubscriptionManager: "0x0000000000000000000000000000000000000000",
    },
  },
  crosschainConfig: {
    subscriptionsSynchronizerConfig: {
      wormholeRelayer: "0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78",
      crossChainTxGasLimit: 50_000_000n,
      SMTMaxDepth: 80,
      subscriptionManagers: [],
      destinations: [],
    },
    subscriptionsStateReceiverConfig: {
      wormholeRelayer: "0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78",
      subscriptionsSynchronizer: "0x0000000000000000000000000000000000000000",
      sourceChainId: 2,
    },
  },
  signatureSBTConfig: {
    name: "Test Shadow SBT",
    symbol: "shSBT",
    signers: [],
  },
};
