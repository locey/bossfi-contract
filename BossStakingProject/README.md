# PumpStakingUpgradeable

This project contains the source code and deployment scripts for the PumpStakingUpgradeable smart contract system.
It supports ETH staking to earn BOSS tokens with immediate or delayed withdrawal options and configurable fees and delay durations.
The contracts use OpenZeppelin upgradeable contracts and are deployable with the UUPS proxy pattern.

## Files

- contracts/BossTokenUpgradeable.sol : Upgradeable ERC20 token for BOSS
- contracts/PumpStakingUpgradeable.sol : Upgradeable staking contract
- scripts/deploy.js : Deployment script for Hardhat
- README.md : This file

## How to deploy

1. Install dependencies:
   ```bash
   npm install
   ```

2. Compile contracts:
   ```bash
   npx hardhat compile
   ```

3. Deploy to a testnet or local node:
   ```bash
   npx hardhat run scripts/deploy.js --network <network>
   ```

Replace `<network>` with your target network such as `sepolia`.