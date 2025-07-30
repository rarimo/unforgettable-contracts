import { IVaultSubscriptionManager } from "@/generated-types/ethers/contracts/vaults/VaultSubscriptionManager";
import { IAccountSubscriptionManager } from "@ethers-v6";

export type DeployConfig = {
  contractsOwner: string;
  vaultsConfig: VaultsConfig;
  accountSubscriptionManagerConfig: AccountSubscriptionManagerConfig;
};

export type VaultsConfig = {
  basePeriodDuration: bigint;
  vaultNameRetentionPeriod: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: IVaultSubscriptionManager.PaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: IVaultSubscriptionManager.SBTTokenUpdateEntryStruct[];
};

export type AccountSubscriptionManagerConfig = {
  basePeriodDuration: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: IAccountSubscriptionManager.PaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: IAccountSubscriptionManager.SBTTokenUpdateEntryStruct[];
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
