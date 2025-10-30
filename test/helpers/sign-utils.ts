import {
  BuySubscriptionTypes,
  MintSignatureSBTTypes,
  RecoverAccountTypes,
  SafeTransactionTypes,
  VaultUpdateEnabledStatusTypes,
  VaultUpdateMasterKeyTypes,
  VaultWithdrawTokensTypes,
} from "@/test/helpers/eip712types";
import { EIP712Upgradeable, SafeMock, SignatureRecoveryStrategy, SignatureSBT, Vault } from "@ethers-v6";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { TypedDataDomain } from "ethers";
import { ethers } from "hardhat";

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

export interface RecoverAccountData {
  account: string;
  object: string;
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

export interface MintSignatureSBTData {
  recipient: string;
  tokenId: bigint;
  tokenURI: string;
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
  sigSubscriptionModule: any,
  account: SignerWithAddress,
  data: BuySubscriptionData,
): Promise<string> {
  const domain = await getDomain(sigSubscriptionModule as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, BuySubscriptionTypes, {
    sender: data.sender,
    duration: data.duration,
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
    objectHash: ethers.keccak256(data.object),
    nonce: data.nonce,
  });
}

export async function getSafeTransactionSignature(
  safe: SafeMock,
  account: SignerWithAddress,
  data: SafeTransactionData,
): Promise<string> {
  const domain: TypedDataDomain = {
    chainId: (await ethers.provider.getNetwork()).chainId,
    verifyingContract: await safe.getAddress(),
  };

  return await account.signTypedData(domain, SafeTransactionTypes, data);
}

export async function getMintSigSBTSignature(
  sigSBT: SignatureSBT,
  account: SignerWithAddress,
  data: MintSignatureSBTData,
): Promise<string> {
  const domain = await getDomain(sigSBT as unknown as EIP712Upgradeable);

  return await account.signTypedData(domain, MintSignatureSBTTypes, {
    recipient: data.recipient,
    tokenId: data.tokenId,
    tokenURIHash: ethers.keccak256(data.tokenURI),
  });
}
