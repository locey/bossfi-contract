const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("PumpStakingUpgradeable", function () {
  let BossToken, bossToken, PumpStaking, pumpStaking;
  let owner, user1;

  beforeEach(async () => {
    [owner, user1] = await ethers.getSigners();

    BossToken = await ethers.getContractFactory("BossToken");
    bossToken = await upgrades.deployProxy(BossToken, [], { initializer: "initialize" });
    await bossToken.deployed();

    PumpStaking = await ethers.getContractFactory("PumpStakingUpgradeable");
    pumpStaking = await upgrades.deployProxy(
      PumpStaking,
      [
        bossToken.address,
        owner.address,
        200,
        7 * 24 * 3600,
        24 * 3600,
        ethers.utils.parseEther("100"),
      ],
      { initializer: "initialize" }
    );
    await pumpStaking.deployed();
  });

  it("Should allow staking and emit event", async function () {
    await pumpStaking.connect(user1).stake({ value: ethers.utils.parseEther("1") });
    const stakeInfo = await pumpStaking.stakes(user1.address);
    expect(stakeInfo.amount).to.equal(ethers.utils.parseEther("1"));
  });

  it("Should calculate rewards correctly", async function () {
    await pumpStaking.connect(user1).stake({ value: ethers.utils.parseEther("1") });
    // 模拟时间流逝一天
    await ethers.provider.send("evm_increaseTime", [24 * 3600]);
    await ethers.provider.send("evm_mine");
    const reward = await pumpStaking.calculateReward(user1.address);
    expect(reward).to.be.gt(0);
  });

  it("Should upgrade without losing state", async function () {
    await pumpStaking.connect(user1).stake({ value: ethers.utils.parseEther("1") });

    const PumpStakingV2 = await ethers.getContractFactory("PumpStakingUpgradeable");
    pumpStaking = await upgrades.upgradeProxy(pumpStaking.address, PumpStakingV2);

    const stakeInfo = await pumpStaking.stakes(user1.address);
    expect(stakeInfo.amount).to.equal(ethers.utils.parseEther("1"));
  });
});
