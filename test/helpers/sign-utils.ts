import {
  BuySubscriptionTypes,
  RecoverAccountTypes,
  SafeTransactionTypes,
  UpdateVaultNameTypes,
  VaultUpdateEnabledStatusTypes,
  VaultUpdateMasterKeyTypes,
  VaultWithdrawTokensTypes,
} from "@/test/helpers/eip712types";
import { EIP712Upgradeable, Safe, SignatureRecoveryStrategy, Vault, VaultSubscriptionManager } from "@ethers-v6";

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

export interface UpdateVaultNameData {
  account: string;
  vaultName: string;
  nonce: bigint;
}

export interface RecoverAccountData {
  account: string;
  objectHash: string;
  nonce: bigint;
}

export interface SafeTransactionData {
  to: string;
  value: bigint;
  data: string;
  operation: bigint;
  safeTxGas: bigint;
  baseGas: bigint;
  gasPrice: bigint;
  gasToken: string;
  refundReceiver: string;
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

export async function getUpdateVaultNameSignature(
  vaultSubscriptionManager: VaultSubscriptionManager,
  account: SignerWithAddress,
  data: UpdateVaultNameData,
): Promise<string> {
  const domain = await getDomain(vaultSubscriptionManager as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, UpdateVaultNameTypes, {
    account: data.account,
    vaultName: data.vaultName,
    nonce: data.nonce,
  });
}

export async function getRecoverAccountSignature(
  signatureRecoveryStrategy: SignatureRecoveryStrategy,
  account: SignerWithAddress,
  data: RecoverAccountData,
): Promise<string> {
  const domain = await getDomain(signatureRecoveryStrategy as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, RecoverAccountTypes, {
    account: data.account,
    objectHash: data.objectHash,
    nonce: data.nonce,
  });
}

export async function getSafeTransactionSignature(
  safe: Safe,
  account: SignerWithAddress,
  data: SafeTransactionData,
): Promise<string> {
  const domain: TypedDataDomain = {
    chainId: await safe.getChainId(),
    verifyingContract: await safe.getAddress(),
  };

  return await account.signTypedData(domain, SafeTransactionTypes, data);
}
