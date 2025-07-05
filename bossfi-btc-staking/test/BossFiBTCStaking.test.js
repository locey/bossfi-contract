const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BossFiBTCStaking", function () {
  let owner, user, operator, other;
  let BossFiReceiptToken, BossFiBTCStaking, MockToken;
  let receiptToken, staking, wbtc, fbtc;
  let receiptTokenAddress, stakingAddress;

  beforeEach(async function () {
    [owner, user, operator, other] = await ethers.getSigners();

    try {
      // 部署MockToken（模拟WBTC、FBTC）
      MockToken = await ethers.getContractFactory("MockToken");
      wbtc = await MockToken.deploy("Wrapped BTC", "WBTC", 8);
      await wbtc.waitForDeployment();
      fbtc = await MockToken.deploy("Fake BTC", "FBTC", 8);
      await fbtc.waitForDeployment();

      // 部署收据代币
      BossFiReceiptToken = await ethers.getContractFactory("BossFiReceiptToken");
      receiptToken = await BossFiReceiptToken.deploy();
      await receiptToken.waitForDeployment();
      receiptTokenAddress = await receiptToken.getAddress();

      // 部署主质押合约（使用构造函数）
      BossFiBTCStaking = await ethers.getContractFactory("BossFiBTCStaking");
      staking = await BossFiBTCStaking.deploy(receiptTokenAddress, operator.address);
      await staking.waitForDeployment();
      stakingAddress = await staking.getAddress();

      // 设置收据代币的质押合约
      await receiptToken.setStakingContract(stakingAddress);

      // 添加支持的代币
      await staking.addSupportedToken(wbtc.target, 8);
      await staking.addSupportedToken(fbtc.target, 8);

      // 给user分配WBTC和FBTC
      await wbtc.mint(user.address, ethers.parseUnits("1", 8));
      await fbtc.mint(user.address, ethers.parseUnits("2", 8));
    } catch (error) {
      console.error("Setup error:", error);
      throw error;
    }
  });

  it("should allow staking supported tokens and mint receipt", async function () {
    const amount = ethers.parseUnits("0.1", 8);
    await wbtc.connect(user).approve(stakingAddress, amount);
    await expect(staking.connect(user).stake(wbtc.target, amount))
      .to.emit(staking, "Stake")
      .withArgs(user.address, wbtc.target, amount);
    expect(await receiptToken.balanceOf(user.address)).to.equal(amount);
  });

  it("should not allow staking unsupported token", async function () {
    const MockToken = await ethers.getContractFactory("MockToken");
    const notSupported = await MockToken.deploy("NotSupported", "NS", 8);
    await notSupported.waitForDeployment();
    await notSupported.mint(user.address, 100000000);
    await notSupported.connect(user).approve(stakingAddress, 100000000);
    await expect(
      staking.connect(user).stake(notSupported.target, 100000000)
    ).to.be.revertedWith("BossFi: unsupported token");
  });

  it("should allow unstake request and burn receipt", async function () {
    const amount = ethers.parseUnits("0.2", 8);
    await fbtc.connect(user).approve(stakingAddress, amount);
    await staking.connect(user).stake(fbtc.target, amount);
    expect(await receiptToken.balanceOf(user.address)).to.equal(amount);
    await staking.connect(owner).setOnlyAllowStake(false);
    await staking.connect(user).unstakeRequest(amount);
    expect(await receiptToken.balanceOf(user.address)).to.equal(0);
  });

  it("should accumulate and claim points", async function () {
    const amount = ethers.parseUnits("0.5", 8);
    await wbtc.connect(user).approve(stakingAddress, amount);
    await staking.connect(user).stake(wbtc.target, amount);
    // 模拟时间流逝
    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]); // 1天
    await ethers.provider.send("evm_mine");
    await staking.connect(owner).setOnlyAllowStake(false);
    await expect(staking.connect(user).claimPoints())
      .to.emit(staking, "PointsClaimed");
    const info = await staking.getUserInfo(user.address);
    expect(info.totalPoints).to.be.gt(0);
  });

  it("should not allow claim points if no pending points", async function () {
    await expect(staking.connect(user).claimPoints()).to.be.revertedWith("BossFi: no points to claim");
  });

  it("should allow only owner to add/remove supported token", async function () {
    await expect(staking.connect(user).addSupportedToken(other.address, 8)).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(staking.connect(owner).removeSupportedToken(wbtc.target)).to.emit(staking, "SupportedTokenRemoved");
  });
});

// MockToken合约（仅测试用）
// SPDX-License-Identifier: MIT
const { Contract } = require("ethers");
const { artifacts } = require("hardhat");

if (!artifacts.readArtifactSync("MockToken")) {
  const fs = require("fs");
  fs.writeFileSync(
    "contracts/MockToken.sol",
    `// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\nimport \'@openzeppelin/contracts/token/ERC20/ERC20.sol\';\ncontract MockToken is ERC20 {\n    uint8 private _decimals;\n    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {\n        _decimals = decimals_;\n    }\n    function decimals() public view override returns (uint8) { return _decimals; }\n    function mint(address to, uint256 amount) public { _mint(to, amount); }\n}`
  );
} 