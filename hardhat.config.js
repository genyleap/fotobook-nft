require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "paris",
      viaIR: true,
      debug: {
        revertStrings: "strip"
      }
    }
  },
  networks: {
    hardhat: {},
    baseSepolia: {
      url: process.env.ALCHEMY_URL || "https://base-sepolia.g.alchemy.com/v2/?????",
      accounts: [
        process.env.PRIVATE_KEY || "0xYOUR_OWNER_PRIVATE_KEY",
        process.env.SECOND_PRIVATE_KEY || "0xYOUR_ADDR1_PRIVATE_KEY"
      ],
      chainId: 84532
    }
  },
  etherscan: {
    apiKey: {
      baseSepolia: process.env.ETHERSCAN_API_KEY
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  }
};
