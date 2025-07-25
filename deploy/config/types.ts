import { IVaultSubscriptionManager } from "@/generated-types/ethers/contracts/vaults/VaultSubscriptionManager";

export type DeployConfig = {
  contractsOwner: string;
  vaultsConfig: VaultsConfig;
};

export type VaultsConfig = {
  basePeriodDuration: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: IVaultSubscriptionManager.PaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: IVaultSubscriptionManager.SBTTokenUpdateEntryStruct[];
};

export type PaymentTokenConfig = {
  paymentToken: string;
  baseSubscriptionCost: bigint;
};

export type SBTTokenConfig = {
  sbtToken: string;
  subscriptionTimePerToken: bigint;
};
