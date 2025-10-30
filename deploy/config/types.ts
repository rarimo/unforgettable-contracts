import { IBaseSideChainSubscriptionManager } from "@/generated-types/ethers/contracts/core/subscription/BaseSideChainSubscriptionManager";
import {
  ICrossChainModule,
  ISBTPaymentModule,
  ISignatureSubscriptionModule,
  ITokensPaymentModule,
} from "@/generated-types/ethers/contracts/core/subscription/BaseSubscriptionManager";
import { ISubscriptionsStateReceiver } from "@/generated-types/ethers/contracts/crosschain/SubscriptionsStateReceiver";
import { ISubscriptionsSynchronizer } from "@/generated-types/ethers/contracts/crosschain/SubscriptionsSynchronizer";

export type DeployConfig = {
  contractsOwner: string;
  reservedRMOConfig: ReservedRMOConfig;
  vaultSubscriptionManagerConfig: VaultSubscriptionManagerConfig;
  accountSubscriptionManagerConfig: AccountSubscriptionManagerConfig;
  sideChainSubscriptionManagerConfig: SideChainSubscriptionManagerConfig;
  crosschainConfig: CrosschainConfig;
  signatureSBTConfig?: SignatureSBTConfig;
};

export type ReservedRMOConfig = {
  reservedTokensAmountPerAddress: bigint;
};

export type SignatureSBTConfig = {
  name: string;
  symbol: string;
  signers: string[];
};

export type VaultSubscriptionManagerConfig = {
  paymentTokenModuleConfig: ITokensPaymentModule.TokensPaymentModuleInitDataStruct;
  sbtPaymentModuleConfig: ISBTPaymentModule.SBTPaymentModuleInitDataStruct;
  signatureSubscriptionModuleConfig: ISignatureSubscriptionModule.SigSubscriptionModuleInitDataStruct;
  crossChainModuleConfig: ICrossChainModule.CrossChainModuleInitDataStruct;
};

export type AccountSubscriptionManagerConfig = {
  paymentTokenModuleConfig: ITokensPaymentModule.TokensPaymentModuleInitDataStruct;
  sbtPaymentModuleConfig: ISBTPaymentModule.SBTPaymentModuleInitDataStruct;
  signatureSubscriptionModuleConfig: ISignatureSubscriptionModule.SigSubscriptionModuleInitDataStruct;
  crossChainModuleConfig: ICrossChainModule.CrossChainModuleInitDataStruct;
};

export type SideChainSubscriptionManagerConfig = {
  baseSideChainSubscriptionManagerConfig: IBaseSideChainSubscriptionManager.BaseSideChainSubscriptionManagerInitDataStruct;
};

export type CrosschainConfig = {
  subscriptionsSynchronizerConfig: ISubscriptionsSynchronizer.SubscriptionsSynchronizerInitDataStruct;
  subscriptionsStateReceiverConfig: ISubscriptionsStateReceiver.SubscriptionsStateReceiverInitDataStruct;
};
