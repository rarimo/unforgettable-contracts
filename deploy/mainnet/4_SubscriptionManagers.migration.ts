import { AccountSubscriptionManager__factory, SideChainSubscriptionManager__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const accountSubscriptionManager = await deployer.deployERC1967Proxy(AccountSubscriptionManager__factory, "0x", {
    name: "AccountSubscriptionManager",
  });

  const sideChainSubscriptionManager = await deployer.deployERC1967Proxy(SideChainSubscriptionManager__factory, "0x", {
    name: "SideChainSubscriptionManager",
  });

  Reporter.reportContracts(
    ["AccountSubscriptionManager", await accountSubscriptionManager.getAddress()],
    ["SideChainSubscriptionManager", await sideChainSubscriptionManager.getAddress()],
  );
};
