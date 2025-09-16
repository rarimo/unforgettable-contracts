import { SubscriptionsSynchronizer__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const subscriptionsSynchronizer = await deployer.deployERC1967Proxy(SubscriptionsSynchronizer__factory, "0x", {
    name: "SubscriptionsSynchronizer",
  });

  Reporter.reportContracts(["SubscriptionsSynchronizer", await subscriptionsSynchronizer.getAddress()]);
};
