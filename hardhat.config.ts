import { HardhatUserConfig } from 'hardhat/config';
import hardhatToolboxViemPlugin from '@nomicfoundation/hardhat-toolbox-viem';
import hardhatVerify from '@nomicfoundation/hardhat-verify';
import { SEPOLIA_RPC_URL, SEPOLIA_PRIVATE_KEY, ETHERSCAN_API_KEY } from './config/env';

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin, hardhatVerify],
  solidity: {
    profiles: {
      default: {
        version: '0.8.28'
      },
      production: {
        version: '0.8.28',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    }
  },
  networks: {
    hardhatMainnet: {
      type: 'edr-simulated',
      chainType: 'l1'
    },
    hardhatOp: {
      type: 'edr-simulated',
      chainType: 'op'
    },
    sepolia: {
      type: 'http',
      chainType: 'l1',
      url: SEPOLIA_RPC_URL,
      accounts: [SEPOLIA_PRIVATE_KEY]
    }
  },
  verify: {
    etherscan: {
      apiKey: ETHERSCAN_API_KEY
    }
  }
};

export default config;
