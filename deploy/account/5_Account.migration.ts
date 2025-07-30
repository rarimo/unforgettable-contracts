import { Account__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

import { ZeroAddress } from "ethers";

export = async (deployer: Deployer) => {
  const accountInitData = Account__factory.createInterface().encodeFunctionData("initialize(address)", [ZeroAddress]);

  await deployer.deployERC1967Proxy(Account__factory, accountInitData, {
    name: "Account",
  });
};
