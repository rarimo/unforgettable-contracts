import {
  BuySubscriptionTypes,
  VaultUpdateEnabledStatusTypes,
  VaultUpdateMasterKeyTypes,
  VaultWithdrawTokensTypes,
} from "@/test/helpers/eip712types";
import { EIP712Upgradeable, Vault, VaultSubscriptionManager } from "@ethers-v6";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { TypedDataDomain } from "ethers";

export interface UpdateDisabledStatusData {
  enabled: boolean;
  nonce: bigint;
}

export interface UpdateMasterKeyData {
  newMasterKey: string;
  nonce: bigint;
}

export interface WithdrawTokensData {
  token: string;
  to: string;
  amount: bigint;
  nonce: bigint;
}

export interface BuySubscriptionData {
  sender: string;
  duration: bigint;
  nonce: bigint;
}

export async function getDomain(contract: EIP712Upgradeable): Promise<TypedDataDomain> {
  const { fields, name, version, chainId, verifyingContract, salt, extensions } = await contract.eip712Domain();

  if (extensions.length > 0) {
    throw Error("Extensions not implemented");
  }

  const domain: TypedDataDomain = {
    name,
    version,
    chainId,
    verifyingContract,
    salt,
  };

  const domainFieldNames: Array<string> = ["name", "version", "chainId", "verifyingContract", "salt"];

  for (const [i, name] of domainFieldNames.entries()) {
    if (!((fields as any) & (1 << i))) {
      delete (domain as any)[name];
    }
  }

  return domain;
}

export async function getUpdateEnabledStatusSignature(
  vault: Vault,
  account: SignerWithAddress,
  data: UpdateDisabledStatusData,
): Promise<string> {
  const domain = await getDomain(vault as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, VaultUpdateEnabledStatusTypes, {
    enabled: data.enabled,
    nonce: data.nonce,
  });
}

export async function getUpdateMasterKeySignature(
  vault: Vault,
  account: SignerWithAddress,
  data: UpdateMasterKeyData,
): Promise<string> {
  const domain = await getDomain(vault as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, VaultUpdateMasterKeyTypes, {
    newMasterKey: data.newMasterKey,
    nonce: data.nonce,
  });
}

export async function getWithdrawTokensSignature(
  vault: Vault,
  account: SignerWithAddress,
  data: WithdrawTokensData,
): Promise<string> {
  const domain = await getDomain(vault as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, VaultWithdrawTokensTypes, {
    token: data.token,
    to: data.to,
    amount: data.amount,
    nonce: data.nonce,
  });
}

export async function getBuySubscriptionSignature(
  vaultSubscriptionManager: VaultSubscriptionManager,
  account: SignerWithAddress,
  data: BuySubscriptionData,
): Promise<string> {
  const domain = await getDomain(vaultSubscriptionManager as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, BuySubscriptionTypes, {
    sender: data.sender,
    duration: data.duration,
    nonce: data.nonce,
  });
}
