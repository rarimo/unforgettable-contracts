import { ETHER_ADDR, PRECISION, wei } from "@/scripts";

import { ethers } from "hardhat";

import { DeployConfig, HelperDataDeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  reservedRMOConfig: {
    reservedTokensAmountPerAddress: wei(100, 18),
  },
  vaultSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 3600n * 24n * 30n,
      discountEntries: [],
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
    crossChainModuleConfig: {
      subscriptionsSynchronizer: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    },
  },
  accountSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 3600n * 24n * 30n,
      discountEntries: [],
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
    crossChainModuleConfig: {
      subscriptionsSynchronizer: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    },
  },
  sideChainSubscriptionManagerConfig: {
    baseSideChainSubscriptionManagerConfig: {
      subscriptionsStateReceiver: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
      sourceSubscriptionManager: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
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
      subscriptionsSynchronizer: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
      sourceChainId: "2",
    },
  },
};

export const helperDataDeployConfig: HelperDataDeployConfig = {
  helperDataFactoryConfig: {
    helperDataManagers: [],
  },
  helperDataSubscriptionManagerConfig: {
    paymentTokenModuleConfig: {
      basePaymentPeriod: 3600n * 24n * 30n,
      discountEntries: [],
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
    crossChainModuleConfig: {
      subscriptionsSynchronizer: ethers.ZeroAddress,
    },
  },
};
