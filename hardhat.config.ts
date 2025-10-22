import type { HardhatUserConfig } from "hardhat/config";
import { configVariable } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatViem from "@nomicfoundation/hardhat-viem";
import hardhatIgnitionPlugin from "@nomicfoundation/hardhat-ignition";
import hardhatVerify from "@nomicfoundation/hardhat-verify";

import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  plugins: [
    hardhatToolboxMochaEthersPlugin, 
    hardhatViem, 
    hardhatIgnitionPlugin,
    hardhatVerify
  ],
  solidity: {
    profiles: {
      default: {
        version: "0.8.30",
      },
      production: {
        version: "0.8.30",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    baseSepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("BASE_SEPOLIA_RPC_URL"),
      accounts: [configVariable("PRIVATE_KEY")],
    }
  },
  verify: {
    etherscan: {
      apiKey: "YOUR_ETHERSCAN_API_KEY",
    },
    blockscout: {
      enabled: true,
    },
  }
};

export default config;
