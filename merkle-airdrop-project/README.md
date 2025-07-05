# Merkle Airdrop Project

这是一个基于 Merkle Tree 的代币空投项目，支持高效的批量空投验证。

## 功能特性

- ✅ Merkle Tree 验证机制
- ✅ 防止重复领取
- ✅ 支持批量用户验证
- ✅ 完整的测试覆盖
- ✅ 自动化部署脚本
- ✅ Merkle Proof 生成工具

## 项目结构

```
merkle-airdrop-project/
├── contracts/
│   ├── MerkleAirdrop.sol      # 主合约
│   └── MockERC20.sol          # 测试代币
├── scripts/
│   ├── deploy.js              # 部署脚本
│   └── generate-merkle-proof.js # Merkle proof 生成脚本
├── test/
│   └── MerkleAirdrop.test.js  # 测试文件
├── data/
│   ├── users.json             # 用户数据 (JSON格式)
│   └── users.csv              # 用户数据 (CSV格式)
└── package.json
```

## 快速开始

### 1. 安装依赖

```bash
npm install
```

### 2. 编译合约

```bash
npm run compile
```

### 3. 运行测试

```bash
npm test
```

### 4. 生成 Merkle Proof

```bash
npm run generate-proof
```

这将：
- 读取用户数据
- 生成 Merkle Tree
- 计算 Merkle Root
- 为每个用户生成 proof
- 保存结果到 `merkle-proofs.json` 和 `frontend-claims.json`

### 5. 部署合约

#### 本地部署
```bash
npm run deploy:local
```

#### 测试网部署
```bash
npm run deploy
```

## 用户数据格式

### JSON 格式
```json
[
  {
    "address": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "amount": 100
  },
  {
    "address": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    "amount": 200
  }
]
```

### CSV 格式
```csv
address,amount
0x70997970C51812dc3A010C7d01b50e0d17dc79C8,100
0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,200
```

## 合约功能

### MerkleAirdrop.sol

- `claim(bytes32[] calldata proof)` - 用户领取代币
- `setMerkleRoot(bytes32 _merkleRoot)` - 管理员更新 Merkle root
- `withdrawTokens(address to, uint256 amount)` - 管理员提取代币

### 安全特性

- 防止重复领取
- 只有 Merkle root 中的用户才能领取
- 管理员可以更新 Merkle root
- 管理员可以提取合约中的代币

## 前端集成

生成的 `frontend-claims.json` 文件可以直接用于前端：

```javascript
import claimsData from './frontend-claims.json';

// 获取用户的 proof
const userClaim = claimsData.claims.find(
  claim => claim.address.toLowerCase() === userAddress.toLowerCase()
);

if (userClaim) {
  const proof = userClaim.proof;
  const amount = userClaim.amount;
  
  // 调用合约 claim 函数
  await airdropContract.claim(proof);
}
```

## 脚本命令

| 命令 | 描述 |
|------|------|
| `npm test` | 运行测试 |
| `npm run compile` | 编译合约 |
| `npm run generate-proof` | 生成 Merkle proof |
| `npm run deploy:local` | 本地部署 |
| `npm run deploy` | 测试网部署 |

## 输出文件

- `merkle-proofs.json` - 完整的 Merkle proof 数据
- `frontend-claims.json` - 前端可用的简化格式
- `deployment.json` - 部署信息

## 注意事项

1. 确保用户地址格式正确（以太坊地址格式）
2. 生成 Merkle proof 后，用户数据不能更改
3. 部署前请确认 Merkle root 正确
4. 测试网部署需要配置环境变量（INFURA_API_KEY, PRIVATE_KEY）

## 许可证

MIT 