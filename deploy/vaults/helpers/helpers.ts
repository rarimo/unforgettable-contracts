import { ICreateX } from "@/generated-types/ethers";

import { ethers } from "hardhat";

export async function getVaultFactoryAddr(createXDeployer: ICreateX, signerAddr: string): Promise<string> {
  const salt = getVaultFactorySalt(signerAddr);
  const guardedSalt = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(["address", "bytes32"], [signerAddr, salt]),
  );

  return await createXDeployer.computeCreate3Address(guardedSalt);
}

export function getVaultFactorySalt(signerAddr: string): string {
  return `${signerAddr}00004e6f6e204f626c697461`;
}
