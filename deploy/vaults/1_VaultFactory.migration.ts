import { ERC1967Proxy__factory, ICreateX__factory, VaultFactory__factory, Vault__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getVaultFactoryAddr, getVaultFactorySalt } from "./helpers/helpers";

export = async (deployer: Deployer) => {
  const createXDeployer = await deployer.deployed(ICreateX__factory, "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed");

  const vault = await deployer.deploy(Vault__factory);
  const vaultFactoryImpl = await deployer.deploy(VaultFactory__factory);

  const constructorArgsEncoded = ERC1967Proxy__factory.createInterface().encodeDeploy([
    await vaultFactoryImpl.getAddress(),
    "0x",
  ]);
  const erc1967ProxyInitcode = ERC1967Proxy__factory.bytecode + constructorArgsEncoded.slice(2);

  const signerAddr = await (await deployer.getSigner()).getAddress();

  const salt = getVaultFactorySalt(signerAddr);
  const vaultFactoryProxyAddr = await getVaultFactoryAddr(createXDeployer, signerAddr);

  await createXDeployer.deployCreate3(salt, erc1967ProxyInitcode);

  Reporter.reportContracts(
    ["VaultImpl", await vault.getAddress()],
    ["VaultFactoryImpl", await vaultFactoryImpl.getAddress()],
    ["VaultFactory", vaultFactoryProxyAddr],
  );
};
