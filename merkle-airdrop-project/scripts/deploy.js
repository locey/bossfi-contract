// scripts/deploy.js
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("🚀 使用账户部署合约:", await deployer.getAddress());

  // 检查是否有生成的 Merkle root
  const merkleProofsPath = path.join(__dirname, "../merkle-proofs.json");
  let merkleRoot = "0x0000000000000000000000000000000000000000000000000000000000000000"; // 默认值
  
  if (fs.existsSync(merkleProofsPath)) {
    const merkleData = JSON.parse(fs.readFileSync(merkleProofsPath, 'utf8'));
    merkleRoot = merkleData.merkleRoot;
    console.log("✅ 使用生成的 Merkle Root:", merkleRoot);
  } else {
    console.log("⚠️  未找到 merkle-proofs.json，使用默认 Merkle Root");
    console.log("💡 请先运行: npx hardhat run scripts/generate-merkle-proof.js");
  }

  // 部署 MockERC20 Token (用于测试)
  console.log("\n📦 部署 MockERC20 Token...");
  const Token = await ethers.getContractFactory("MockERC20");
  const token = await Token.deploy("Test Token", "TEST");
  console.log("✅ MockERC20 Token 已部署:", await token.getAddress());

  // 部署 MerkleAirdrop 合约
  console.log("\n📦 部署 MerkleAirdrop 合约...");
  const MerkleAirdrop = await ethers.getContractFactory("MerkleAirdrop");
  const airdrop = await MerkleAirdrop.deploy(merkleRoot, await token.getAddress());
  console.log("✅ MerkleAirdrop 合约已部署:", await airdrop.getAddress());

  // 保存部署信息
  const deploymentInfo = {
    network: "hardhat", // 可以根据需要修改
    deployedAt: new Date().toISOString(),
    deployer: await deployer.getAddress(),
    contracts: {
      token: await token.getAddress(),
      airdrop: await airdrop.getAddress(),
      merkleRoot: merkleRoot
    }
  };

  const deploymentPath = path.join(__dirname, "../deployment.json");
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("\n💾 部署信息已保存到:", deploymentPath);

  console.log("\n🎉 部署完成!");
  console.log("📋 部署摘要:");
  console.log(`   Token: ${await token.getAddress()}`);
  console.log(`   Airdrop: ${await airdrop.getAddress()}`);
  console.log(`   Merkle Root: ${merkleRoot}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });
