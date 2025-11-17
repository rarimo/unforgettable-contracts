import { SignatureSBT__factory } from "@ethers-v6";

import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { getConfig } from "../config/config";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  if (config.signatureSBTConfig) {
    const signatureSBT = await deployer.deployERC1967Proxy(SignatureSBT__factory, "0x", {
      name: "SignatureSBT",
    });

    await signatureSBT.initialize(config.signatureSBTConfig.name, config.signatureSBTConfig.symbol);

    if (config.signatureSBTConfig.signers.length > 0) {
      await signatureSBT.addSigners(config.signatureSBTConfig.signers);
    }

    Reporter.reportContracts(["SignatureSBT", await signatureSBT.getAddress()]);
  }
};
