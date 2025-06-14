const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 部署参数
  const name = "Boss NFT";
  const symbol = "BOSS";
  const baseTokenURI = "https://api.your-backend.com/nft/metadata/"; // 替换为你的后端 API 地址

  // 部署 NFT 合约
  const BossNFTUpgradeable = await ethers.getContractFactory("BossNFTUpgradeable");
  const bossNFT = await upgrades.deployProxy(
    BossNFTUpgradeable,
    [name, symbol, baseTokenURI],
    { initializer: 'initialize' }
  );
  await bossNFT.deployed();

  console.log("BossNFTUpgradeable deployed to:", bossNFT.address);
  console.log("Deployment parameters:");
  console.log("- Name:", name);
  console.log("- Symbol:", symbol);
  console.log("- Base Token URI:", baseTokenURI);
  console.log("- Initial Minting Status: Enabled");

  // 验证合约
  console.log("\nVerifying contract...");
  try {
    await hre.run("verify:verify", {
      address: bossNFT.address,
      constructorArguments: [],
    });
    console.log("Contract verified successfully");
  } catch (error) {
    console.log("Verification failed:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });