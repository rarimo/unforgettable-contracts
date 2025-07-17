import { DeployConfig } from "./types";

export const deployConfig: DeployConfig = {
  contractsOwner: "",
  vaultsConfig: {
    basePeriodDuration: 3600n * 24n * 30n,
    subscriptionSigner: "",
    paymentTokenConfigs: [],
    sbtTokenConfigs: [],
  },
};
