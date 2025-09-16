import { SubscriptionsStateReceiver__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

export = async (deployer: Deployer) => {
  const subscriptionsStateReceiver = await deployer.deployERC1967Proxy(SubscriptionsStateReceiver__factory, "0x", {
    name: "SubscriptionsStateReceiver",
  });

  Reporter.reportContracts(["SubscriptionsStateReceiver", await subscriptionsStateReceiver.getAddress()]);
};
