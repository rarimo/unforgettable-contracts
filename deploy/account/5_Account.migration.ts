import { Account__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  await deployer.deploy(Account__factory);
};
