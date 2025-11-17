import { ETHER_ADDR, wei } from "@scripts";

import { ethers } from "hardhat";

import { DeployConfig, HelperDataDeployConfig } from "./types";

const basePaymentPeriod = 2_629_800n; // 1 month
const oneYear = basePaymentPeriod * 12n; // 1 year

export const deployConfig: DeployConfig = {
  contractsOwner: "0x00D37f35Ec44ecC4e2F54de1FA3208F73d632E59",
  reservedRMOConfig: {
    reservedTokensAmountPerAddress: wei(100, 18),
  },
  vaultSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: basePaymentPeriod, // 1 month
      discountEntries: [],
      durationFactorEntries: [
        {
          duration: oneYear, // 1 year
          factor: 91666667000000000000000000n, // 0.91666667
        },
        {
          duration: oneYear * 2n, // 2 years
          factor: 87500000000000000000000000n, // 0.875
        },
        {
          duration: oneYear * 5n, // 5 years
          factor: 86666667000000000000000000n, // 0.86666667
        },
        {
          duration: oneYear * 10n, // 10 years
          factor: 83333333000000000000000000n, // 0.83333333
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR, // NATIVE ETH
          baseSubscriptionCost: 500000000000000n, // 0.0005 ETH
        },
        {
          paymentToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
          baseSubscriptionCost: 2000000n,
        },
        {
          paymentToken: "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT
          baseSubscriptionCost: 2000000n,
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [
        {
          sbt: "0xF6044AC164740c106246De210D03Bc04FE78cbAb", // ZK Recovery Waitlist SBT
          subscriptionDurationPerToken: oneYear, // 1 year
        },
      ],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "0xE9a5a2f2Da84F02d92E82EbB0A0d875797c770e5",
    },
    crossChainModuleConfig: {
      subscriptionsSynchronizer: "0x0000000000000000000000000000000000000000",
    },
  },
  accountSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: basePaymentPeriod, // 1 month
      discountEntries: [],
      durationFactorEntries: [
        {
          duration: oneYear, // 1 year
          factor: 91666667000000000000000000n, // 0.91666667
        },
        {
          duration: oneYear * 2n, // 2 years
          factor: 87500000000000000000000000n, // 0.875
        },
        {
          duration: oneYear * 5n, // 5 years
          factor: 86666667000000000000000000n, // 0.86666667
        },
        {
          duration: oneYear * 10n, // 10 years
          factor: 83333333000000000000000000n, // 0.83333333
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR, // NATIVE ETH
          baseSubscriptionCost: 500000000000000n, // 0.0005 ETH
        },
        {
          paymentToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
          baseSubscriptionCost: 2000000n,
        },
        {
          paymentToken: "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT
          baseSubscriptionCost: 2000000n,
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [
        {
          sbt: "0xF6044AC164740c106246De210D03Bc04FE78cbAb", // ZK Recovery Waitlist SBT
          subscriptionDurationPerToken: oneYear, // 1 year
        },
      ],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "0xE9a5a2f2Da84F02d92E82EbB0A0d875797c770e5",
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
      wormholeRelayer: "0x27428DD2d3DD32A4D7f7C497eAaa23130d894911",
      crossChainTxGasLimit: 5_000_000n,
      SMTMaxDepth: 80,
      subscriptionManagers: [],
      destinations: [],
    },
    subscriptionsStateReceiverConfig: {
      wormholeRelayer: "0x27428DD2d3DD32A4D7f7C497eAaa23130d894911",
      subscriptionsSynchronizer: "0x0000000000000000000000000000000000000000",
      sourceChainId: 1,
    },
  },
};

export const helperDataDeployConfig: HelperDataDeployConfig = {
  helperDataFactoryConfig: {
    helperDataManagers: [],
  },
  helperDataSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: basePaymentPeriod, // 1 month
      discountEntries: [],
      durationFactorEntries: [
        {
          duration: oneYear, // 1 year
          factor: 91666667000000000000000000n, // 0.91666667
        },
        {
          duration: oneYear * 2n, // 2 years
          factor: 87500000000000000000000000n, // 0.875
        },
        {
          duration: oneYear * 5n, // 5 years
          factor: 86666667000000000000000000n, // 0.86666667
        },
        {
          duration: oneYear * 10n, // 10 years
          factor: 83333333000000000000000000n, // 0.83333333
        },
      ],
      paymentTokenEntries: [
        {
          paymentToken: ETHER_ADDR, // NATIVE ETH
          baseSubscriptionCost: 500000000000000n, // 0.0005 ETH
        },
        {
          paymentToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
          baseSubscriptionCost: 2000000n,
        },
        {
          paymentToken: "0xdAC17F958D2ee523a2206206994597C13D831ec7", // USDT
          baseSubscriptionCost: 2000000n,
        },
      ],
    },
    sbtPaymentModuleConfig: {
      sbtEntries: [],
    },
    signatureSubscriptionModuleConfig: {
      subscriptionSigner: "0x0000000000000000000000000000000000000000",
    },
    crossChainModuleConfig: {
      subscriptionsSynchronizer: ethers.ZeroAddress,
    },
  },
};
