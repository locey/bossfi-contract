const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  // 部署 BossToken
  const BossToken = await ethers.getContractFactory("BossToken");
  const bossToken = await upgrades.deployProxy(BossToken, [], { initializer: 'initialize' });
  await bossToken.deployed();
  console.log("BossToken deployed to:", bossToken.address);

  // 部署 BossStaking
  const BossStaking = await ethers.getContractFactory("BossStaking");
  const bossStaking = await upgrades.deployProxy(
    BossStaking,
    [
      bossToken.address,
      deployer.address, // feeReceiver 直接设置为部署者地址
      200, // 2% feeRate
      7 * 24 * 3600, // 7 天延迟
      24 * 3600, // 1 天最小质押时长
      ethers.utils.parseEther("100") // 单用户最大质押100 ETH
    ],
    { initializer: 'initialize' }
  );
  await bossStaking.deployed();
  console.log("BossStaking deployed to:", bossStaking.address);

  // 设置 BossStaking 为 BossToken 的 minter
  const setMinterTx = await bossToken.setMinter(bossStaking.address);
  await setMinterTx.wait();
  console.log("Set BossStaking as minter of BossToken");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
