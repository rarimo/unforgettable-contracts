import { ERC20Mock__factory, SBTMock__factory } from "@ethers-v6";

import { Deployer } from "@solarity/hardhat-migrate";

type ERC20TokenConfig = {
  name: string;
  symbol: string;
  decimals: bigint;
};

type SBTTokenConfig = {
  name: string;
  symbol: string;
  initialOwners: string[];
};

export = async (deployer: Deployer) => {
  const erc20TokensConfig: ERC20TokenConfig[] = [
    {
      name: "Tether USD",
      symbol: "USDT",
      decimals: 6n,
    },
    {
      name: "Circle USD",
      symbol: "USDC",
      decimals: 6n,
    },
  ];

  const sbtTokensConfigs: SBTTokenConfig[] = [
    {
      name: "Unforgettable Test SBT",
      symbol: "UFSBT",
      initialOwners: [await (await deployer.getSigner()).getAddress()],
    },
  ];

  for (let i = 0; i < erc20TokensConfig.length; i++) {
    const config = erc20TokensConfig[i];

    await deployer.deploy(ERC20Mock__factory, [config.name, config.symbol, config.decimals], {
      name: `${config.symbol} ERC20`,
    });
  }

  for (let i = 0; i < sbtTokensConfigs.length; i++) {
    const config = sbtTokensConfigs[i];

    const sbt = await deployer.deploy(SBTMock__factory, { name: `${config.symbol} SBT` });
    await sbt.initialize(config.name, config.symbol, config.initialOwners);
  }
};

// npx hardhat --network sepolia migrate --verify --namespace utility --only 1
