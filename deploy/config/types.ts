import { IVaultSubscriptionManager } from "@/generated-types/ethers/contracts/vaults/VaultSubscriptionManager";

export type DeployConfig = {
  contractsOwner: string;
  vaultsConfig: VaultsConfig;
};

export type VaultsConfig = {
  basePeriodDuration: bigint;
  vaultNameRetentionPeriod: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: IVaultSubscriptionManager.PaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: IVaultSubscriptionManager.SBTTokenUpdateEntryStruct[];
};

export type PaymentTokenConfig = {
  paymentToken: string;
  baseSubscriptionCost: bigint;
  baseVaultNameCost: bigint;
};

export type SBTTokenConfig = {
  sbtToken: string;
  subscriptionTimePerToken: bigint;
};
