const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 开始生成 Merkle Proof...\n");

  // 示例用户数据 - 你可以从 CSV 或 JSON 文件读取
  const users = [
    { address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", amount: 100 },
    { address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", amount: 200 },
    { address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906", amount: 150 },
    { address: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", amount: 300 },
    { address: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", amount: 250 },
  ];

  console.log(`📋 处理 ${users.length} 个用户地址...`);

  // 生成 Merkle tree
  console.log("🌳 生成 Merkle Tree...");
  
  // 方式1: 只使用地址生成 leaf (与当前合约一致)
  const leavesAddressOnly = users.map((user) => 
    ethers.solidityPackedKeccak256(["address"], [user.address])
  );
  
  // 方式2: 使用地址+数量生成 leaf (如果需要支持不同数量)
  const leavesWithAmount = users.map((user) => 
    ethers.solidityPackedKeccak256(["address", "uint256"], [user.address, user.amount])
  );

  // 创建 Merkle tree (使用地址的方式，与当前合约一致)
  const tree = new MerkleTree(leavesAddressOnly, ethers.keccak256, { sortPairs: true });
  const merkleRoot = tree.getHexRoot();

  console.log(`✅ Merkle Root: ${merkleRoot}\n`);

  // 为每个用户生成 proof
  console.log("🔍 为每个用户生成 proof...");
  const proofs = [];

  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    const leaf = ethers.solidityPackedKeccak256(["address"], [user.address]);
    const proof = tree.getHexProof(leaf);
    
    proofs.push({
      address: user.address,
      amount: user.amount,
      proof: proof,
      leaf: leaf
    });

    console.log(`✅ ${user.address} - ${user.amount} tokens`);
  }

  // 生成输出数据
  const outputData = {
    merkleRoot: merkleRoot,
    users: proofs,
    totalUsers: users.length,
    totalAmount: users.reduce((sum, user) => sum + user.amount, 0),
    generatedAt: new Date().toISOString()
  };

  // 保存到文件
  const outputPath = path.join(__dirname, "../merkle-proofs.json");
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));
  
  console.log(`\n💾 结果已保存到: ${outputPath}`);
  console.log(`📊 总计: ${users.length} 个用户, ${outputData.totalAmount} 个代币`);

  // 生成前端可用的格式
  const frontendData = {
    merkleRoot: merkleRoot,
    claims: proofs.map(p => ({
      address: p.address,
      amount: p.amount,
      proof: p.proof
    }))
  };

  const frontendPath = path.join(__dirname, "../frontend-claims.json");
  fs.writeFileSync(frontendPath, JSON.stringify(frontendData, null, 2));
  
  console.log(`🌐 前端数据已保存到: ${frontendPath}`);

  // 生成部署用的 Merkle root
  console.log(`\n📝 部署合约时使用的 Merkle Root:`);
  console.log(`merkleRoot = "${merkleRoot}";`);

  // 验证 proof 示例
  console.log(`\n🔍 验证 proof 示例:`);
  const firstUser = proofs[0];
  const isValid = tree.verify(firstUser.proof, firstUser.leaf, merkleRoot);
  console.log(`用户 ${firstUser.address} 的 proof 验证结果: ${isValid ? "✅ 有效" : "❌ 无效"}`);

  console.log("\n🎉 Merkle Proof 生成完成!");
}

// 从文件读取用户数据的辅助函数
function loadUsersFromFile(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    
    if (filePath.endsWith('.json')) {
      return JSON.parse(data);
    } else if (filePath.endsWith('.csv')) {
      const lines = data.split('\n').filter(line => line.trim());
      const headers = lines[0].split(',').map(h => h.trim());
      const users = [];
      
      for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split(',').map(v => v.trim());
        const user = {};
        headers.forEach((header, index) => {
          user[header] = values[index];
        });
        users.push(user);
      }
      
      return users;
    }
  } catch (error) {
    console.error(`❌ 读取文件失败: ${error.message}`);
    return null;
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ 生成失败:", error);
      process.exit(1);
    });
}

module.exports = { main, loadUsersFromFile }; 