require('@nomicfoundation/hardhat-ethers');
require('@nomiclabs/hardhat-etherscan');
require('dotenv').config();  // 用于加载环境变量

module.exports = {
  solidity: {
    version: "0.8.20", // 设置 Solidity 版本
    settings: {
      optimizer: {
        enabled: true,  // 启用优化器
        runs: 200,  // 优化的次数
      },
    },
  },
  // 添加网络配置以解决下载问题
  paths: {
    cache: './cache',
    artifacts: './artifacts',
  },
  networks: {
    // 配置 Sepolia 测试网
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],  // 从 .env 文件中加载私钥
    },
  },
  etherscan: {
    // 配置 Etherscan 用于合约验证
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,  // 启用 gas 报告
    currency: 'USD',  // 报告使用的货币
    gasPrice: 21,  // gas 价格
  },
};
