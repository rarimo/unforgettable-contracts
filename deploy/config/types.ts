import { IVaultNameSubscriptionModule } from "@/generated-types/ethers/contracts/interfaces/subscription/IVaultSubscriptionManager";
import { ISBTSubscriptionModule, ISubscriptionManager } from "@ethers-v6";

export type DeployConfig = {
  contractsOwner: string;
  vaultsConfig: VaultsConfig;
  accountSubscriptionManagerConfig: AccountSubscriptionManagerConfig;
};

export type VaultsConfig = {
  basePeriodDuration: bigint;
  vaultNameRetentionPeriod: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: ISubscriptionManager.PaymentTokenUpdateEntryStruct[];
  vaultPaymentTokenConfigs: IVaultNameSubscriptionModule.VaultPaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: ISBTSubscriptionModule.SBTTokenUpdateEntryStruct[];
};

export type AccountSubscriptionManagerConfig = {
  basePeriodDuration: bigint;
  subscriptionSigner: string;
  paymentTokenConfigs: ISubscriptionManager.PaymentTokenUpdateEntryStruct[];
  sbtTokenConfigs: ISBTSubscriptionModule.SBTTokenUpdateEntryStruct[];
};
