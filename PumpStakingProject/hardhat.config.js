require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");

const { INFURA_API_KEY, PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
};
