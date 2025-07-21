import { TypedDataField } from "ethers";

export const VaultWithdrawTokensTypes: Record<string, TypedDataField[]> = {
  WithdrawTokens: [
    { name: "token", type: "address" },
    { name: "to", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
};

export const VaultUpdateDisabledStatusTypes: Record<string, TypedDataField[]> = {
  UpdateDisabledStatus: [
    { name: "newDisabledValue", type: "bool" },
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
