const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 1. 部署收据代币
  console.log("Deploying BossFiReceiptToken...");
  const BossFiReceiptToken = await hre.ethers.getContractFactory("BossFiReceiptToken");
  const receiptToken = await BossFiReceiptToken.deploy();
  await receiptToken.waitForDeployment();
  const receiptTokenAddress = await receiptToken.getAddress();
  console.log("BossFiReceiptToken deployed to:", receiptTokenAddress);

  // 2. 部署主质押合约（使用构造函数）
  console.log("Deploying BossFiBTCStaking...");
  const BossFiBTCStaking = await hre.ethers.getContractFactory("BossFiBTCStaking");
  const staking = await BossFiBTCStaking.deploy(receiptTokenAddress, deployer.address);
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  console.log("BossFiBTCStaking deployed to:", stakingAddress);

  // 3. 设置收据代币的质押合约
  console.log("Setting staking contract in receipt token...");
  await receiptToken.setStakingContract(stakingAddress);
  console.log("Receipt token configured");

  // 4. 添加支持的代币（示例：WBTC、FBTC）
  console.log("Adding supported tokens...");
  
  // 这里需要替换为实际的WBTC和FBTC地址
  const WBTC_ADDRESS = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"; // 主网WBTC
  const FBTC_ADDRESS = "0x0000000000000000000000000000000000000000"; // 需要替换为实际地址
  
  await staking.addSupportedToken(WBTC_ADDRESS, 8);
  console.log("WBTC added as supported token");
  
  if (FBTC_ADDRESS !== "0x0000000000000000000000000000000000000000") {
    await staking.addSupportedToken(FBTC_ADDRESS, 8);
    console.log("FBTC added as supported token");
  }

  console.log("\n=== Deployment Summary ===");
  console.log("BossFiReceiptToken:", receiptTokenAddress);
  console.log("BossFiBTCStaking:", stakingAddress);
  console.log("Owner:", deployer.address);
  console.log("Operator:", deployer.address);
  console.log("Supported tokens: WBTC, FBTC");
  console.log("========================\n");

  // 5. 验证合约（可选）
  console.log("Waiting for block confirmations...");
  await receiptToken.deployTransaction.wait(6);
  await staking.deployTransaction.wait(6);

  console.log("Deployment completed successfully!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 