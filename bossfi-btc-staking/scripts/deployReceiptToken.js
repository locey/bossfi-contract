const hre = require("hardhat");

async function main() {
  const BossFiReceiptToken = await hre.ethers.getContractFactory("BossFiReceiptToken");
  const receiptToken = await BossFiReceiptToken.deploy();
  await receiptToken.deployed();
  console.log("BossFiReceiptToken deployed to:", receiptToken.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 