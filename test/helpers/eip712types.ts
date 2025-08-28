import { TypedDataField } from "ethers";

export const VaultWithdrawTokensTypes: Record<string, TypedDataField[]> = {
  WithdrawTokens: [
    { name: "token", type: "address" },
    { name: "to", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
};

export const VaultUpdateEnabledStatusTypes: Record<string, TypedDataField[]> = {
  UpdateEnabledStatus: [
    { name: "enabled", type: "bool" },
    { name: "nonce", type: "uint256" },
  ],
};

export const VaultUpdateMasterKeyTypes: Record<string, TypedDataField[]> = {
  UpdateMasterKey: [
    { name: "newMasterKey", type: "address" },
    { name: "nonce", type: "uint256" },
  ],
};

export const BuySubscriptionTypes: Record<string, TypedDataField[]> = {
  BuySubscription: [
    { name: "sender", type: "address" },
    { name: "duration", type: "uint64" },
    { name: "nonce", type: "uint256" },
  ],
};

export const RecoverAccountTypes: Record<string, TypedDataField[]> = {
  SignatureRecovery: [
    { name: "account", type: "address" },
    { name: "objectHash", type: "bytes32" },
    { name: "nonce", type: "uint256" },
  ],
};
