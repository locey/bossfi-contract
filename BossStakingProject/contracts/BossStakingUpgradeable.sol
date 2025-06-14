// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./BossTokenUpgradeable.sol";

contract BossStaking is Initializable, PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    BossToken public bossToken;
    address public feeReceiver;

    uint256 public constant MAX_FEE = 500; // 5%
    uint256 public feeRate; // 200 = 2%
    uint256 public delayDuration; // 7 days in seconds
    uint256 public minStakeDuration; // 1 day in seconds
    uint256 public maxStakePerUser;

    uint256 public totalStaked;
    uint256 public totalFees;

    struct Stake {
        uint256 amount;
        uint256 lastRewardTime;
        uint256 stakeTime;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public unlockTimes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, bool isInstant);
    event RewardClaimed(address indexed user, uint256 amount);
    event FeeReceiverChanged(address indexed previousReceiver, address indexed newReceiver);
    event FeesClaimed(address indexed receiver, uint256 amount);
    event TreasuryWithdraw(address indexed owner, uint256 amount, uint256 timestamp);
    event TreasuryDeposit(address indexed owner, uint256 amount, uint256 timestamp);

    function initialize(
        address _bossToken,
        address _feeReceiver,
        uint256 _feeRate,
        uint256 _delayDuration,
        uint256 _minStakeDuration,
        uint256 _maxStakePerUser
    ) public initializer {
        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        require(_feeRate <= MAX_FEE, "Fee too high");
        bossToken = BossToken(_bossToken);
        feeReceiver = _feeReceiver;
        feeRate = _feeRate;
        delayDuration = _delayDuration;
        minStakeDuration = _minStakeDuration;
        maxStakePerUser = _maxStakePerUser;
    }

    receive() external payable {
        if (msg.sender != owner()) {
            stake();
        }
    }

    function stake() public payable whenNotPaused {
        require(msg.value > 0, "Cannot stake 0");
        require(stakes[msg.sender].amount + msg.value <= maxStakePerUser, "Exceeds max stake");

        _updateReward(msg.sender);

        stakes[msg.sender].amount += msg.value;
        stakes[msg.sender].stakeTime = block.timestamp;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function _updateReward(address user) internal {
        if (stakes[user].amount > 0) {
            uint256 reward = calculateReward(user);
            if (reward > 0) {
                bossToken.mint(user, reward);
                emit RewardClaimed(user, reward);
            }
        }
        stakes[user].lastRewardTime = block.timestamp;
    }

    function calculateReward(address user) public view returns (uint256) {
        Stake memory s = stakes[user];
        if (s.amount == 0) return 0;

        uint256 duration = block.timestamp - s.lastRewardTime;
        return (s.amount * duration * 1e18) / (1e20 * 86400); // 0.1 token per ETH per day
    }

    function withdrawNow(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot withdraw 0");
        Stake storage s = stakes[msg.sender];
        require(s.amount >= amount, "Insufficient balance");
        require(block.timestamp >= s.stakeTime + minStakeDuration, "Too early");

        _updateReward(msg.sender);

        uint256 fee = (amount * feeRate) / 10000;
        uint256 payout = amount - fee;

        s.amount -= amount;
        totalStaked -= amount;
        totalFees += fee;

        payable(msg.sender).transfer(payout);
        emit Withdrawn(msg.sender, amount, true);
    }

    function withdrawLater(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot withdraw 0");
        Stake storage s = stakes[msg.sender];
        require(s.amount >= amount, "Insufficient balance");
        require(block.timestamp >= s.stakeTime + minStakeDuration, "Too early");

        _updateReward(msg.sender);

        s.amount -= amount;
        totalStaked -= amount;
        pendingWithdrawals[msg.sender] += amount;
        unlockTimes[msg.sender] = block.timestamp + delayDuration;

        emit Withdrawn(msg.sender, amount, false);
    }

    function claimDelayed() external nonReentrant whenNotPaused {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to claim");
        require(block.timestamp >= unlockTimes[msg.sender], "Not unlocked");

        pendingWithdrawals[msg.sender] = 0;
        unlockTimes[msg.sender] = 0;

        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount, false);
    }

    function claimBossToken() external nonReentrant {
        _updateReward(msg.sender);
    }

    function setFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Invalid address");
        emit FeeReceiverChanged(feeReceiver, newReceiver);
        feeReceiver = newReceiver;
    }

    function setStakingParameters(
        uint256 _delayDuration,
        uint256 _minStakeDuration,
        uint256 _maxStakePerUser
    ) external onlyOwner {
        delayDuration = _delayDuration;
        minStakeDuration = _minStakeDuration;
        maxStakePerUser = _maxStakePerUser;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdrawFromTreasury(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit TreasuryWithdraw(owner(), amount, block.timestamp);
    }

    function depositToTreasury() external payable onlyOwner {
        require(msg.value > 0, "Amount must be greater than 0");
        emit TreasuryDeposit(owner(), msg.value, block.timestamp);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyFeeReceiver() {
        require(msg.sender == feeReceiver, "Caller is not the fee receiver");
        _;
    }

    function claimFees() external onlyFeeReceiver nonReentrant {
        require(totalFees > 0, "No fees to claim");
        uint256 amount = totalFees;
        totalFees = 0;
        payable(feeReceiver).transfer(amount);
        emit FeesClaimed(feeReceiver, amount);
    }

    function getTotalFees() external view returns (uint256) {
        return totalFees;
    }
}
