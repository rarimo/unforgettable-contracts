import {
  ISBTPaymentModule,
  ISignatureSubscriptionModule,
  ITokensPaymentModule,
} from "@/generated-types/ethers/contracts/core/subscription/BaseSubscriptionManager";

export type DeployConfig = {
  contractsOwner: string;
  reservedRMOConfig: ReservedRMOConfig;
  vaultSubscriptionManagerConfig: VaultSubscriptionManagerConfig;
  accountSubscriptionManagerConfig: AccountSubscriptionManagerConfig;
};

export type ReservedRMOConfig = {
  reservedTokensAmountPerAddress: bigint;
};

export type VaultSubscriptionManagerConfig = {
  paymentTokenModuleConfig: ITokensPaymentModule.TokensPaymentModuleInitDataStruct;
  sbtPaymentModuleConfig: ISBTPaymentModule.SBTPaymentModuleInitDataStruct;
  signatureSubscriptionModuleConfig: ISignatureSubscriptionModule.SigSubscriptionModuleInitDataStruct;
};

export type AccountSubscriptionManagerConfig = {
  paymentTokenModuleConfig: ITokensPaymentModule.TokensPaymentModuleInitDataStruct;
  sbtPaymentModuleConfig: ISBTPaymentModule.SBTPaymentModuleInitDataStruct;
  signatureSubscriptionModuleConfig: ISignatureSubscriptionModule.SigSubscriptionModuleInitDataStruct;
};
