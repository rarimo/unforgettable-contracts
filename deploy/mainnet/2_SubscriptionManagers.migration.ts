import { AccountSubscriptionManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const accountSubscriptionManager = await deployer.deployERC1967Proxy(AccountSubscriptionManager__factory, "0x", {
    name: "AccountSubscriptionManager",
  });

  Reporter.reportContracts(["AccountSubscriptionManager", await accountSubscriptionManager.getAddress()]);
};
