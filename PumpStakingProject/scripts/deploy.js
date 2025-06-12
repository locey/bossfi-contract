const { ethers, upgrades } = require("hardhat");

async function main() {
  // 部署 BossToken
  const BossToken = await ethers.getContractFactory("BossToken");
  const bossToken = await upgrades.deployProxy(BossToken, [], { initializer: 'initialize' });
  await bossToken.deployed();
  console.log("BossToken deployed to:", bossToken.address);

  // 部署 PumpStakingUpgradeable
  const PumpStaking = await ethers.getContractFactory("PumpStakingUpgradeable");
  const pumpStaking = await upgrades.deployProxy(
    PumpStaking,
    [
      bossToken.address,
      ethers.constants.AddressZero, // feeReceiver 默认 0 地址，后续用 setFeeReceiver 设置
      200, // 2% feeRate
      7 * 24 * 3600, // 7 天延迟
      24 * 3600, // 1 天最小质押时长
      ethers.utils.parseEther("100") // 单用户最大质押100 ETH
    ],
    { initializer: 'initialize' }
  );
  await pumpStaking.deployed();
  console.log("PumpStakingUpgradeable deployed to:", pumpStaking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
