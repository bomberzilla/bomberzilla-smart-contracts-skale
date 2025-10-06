import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "hardhat-chai-matchers-viem";

import env from "dotenv";
env.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 2046399126,
      forking: {
        url: process.env.SKALE_RPC_URL ?? "",
        blockNumber: 20620048,
      },
    },
    skale: {
      url: process.env.SKALE_RPC_URL ?? "",
      chainId: 2046399126,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    skaleTestnet: {
      url: process.env.SKALE_TESTNET_RPC_URL ?? "",
      chainId: 1444673419,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      skale: "empty",
      skaleTestnet: "empty",
    },
    customChains: [
      {
        network: "skale",
        chainId: 2046399126,
        urls: {
          apiURL:
            "https://internal-hubs.explorer.mainnet.skalenodes.com:10021/api",
          browserURL: "https://internal-hubs.explorer.mainnet.skalenodes.com",
        },
      },
      {
        network: "skaleTestnet",
        chainId: 1444673419,
        urls: {
          apiURL:
            "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com/api",
          browserURL:
            "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com/",
        },
      },
    ],
  },
  mocha: {
    timeout: 600000,
  },
};

export default config;
