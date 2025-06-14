const { ethers, upgrades } = require("hardhat");

async function main() {
  const pumpStakingAddress = "你已部署的 PumpStakingUpgradeable 合约地址";

  const PumpStakingV2 = await ethers.getContractFactory("PumpStakingUpgradeable");
  console.log("Upgrading PumpStaking...");
  await upgrades.upgradeProxy(pumpStakingAddress, PumpStakingV2);
  console.log("PumpStaking upgraded");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
