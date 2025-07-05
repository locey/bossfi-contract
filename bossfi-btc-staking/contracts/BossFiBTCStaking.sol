// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BossFiReceiptToken.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

using SafeERC20 for IERC20;
using SafeCast for uint256;

/**
 * @title BossFiBTCStaking
 * @dev BossFi比特币质押合约，支持WBTC、FBTC等代币质押
 * 用户质押比特币代币后获得收据代币和积分奖励
 */
contract BossFiBTCStaking is Ownable, Pausable {
    // ============================= 常量 =============================
    uint8 constant public MAX_DATE_SLOT = 10;
    uint256 constant public POINTS_PER_SATOSHI_PER_DAY = 1; // 每天每satoshi获得1积分
    uint256 constant public MIN_STAKE_AMOUNT = 1000; // 最小质押数量 (0.00001 BTC)
    uint256 constant public NORMAL_UNSTAKE_FEE = 0; // 正常解质押费用 0%
    uint256 constant public INSTANT_UNSTAKE_FEE = 300; // 即时解质押费用 3%

    // ============================= 状态变量 =============================
    BossFiReceiptToken public receiptToken;
    mapping(address => bool) public supportedTokens; // 支持的代币列表
    mapping(address => uint8) public tokenDecimals; // 代币小数位数
    
    // 质押相关变量 (以8位小数计算)
    uint256 public totalStakingAmount;      // 当前质押总量
    uint256 public totalStakingCap;         // 质押上限
    uint256 public totalRequestedAmount;    // 总请求解质押数量
    uint256 public totalClaimableAmount;    // 总可领取数量
    uint256 public pendingStakeAmount;      // 今日待质押数量
    uint256 public collectedFee;            // 总收取费用

    address public operator;                // 操作员地址
    bool public onlyAllowStake;             // 是否只允许质押

    // 用户解质押请求
    mapping(address => mapping(uint8 => uint256)) public pendingUnstakeTime;
    mapping(address => mapping(uint8 => uint256)) public pendingUnstakeAmount;
    
    // 用户积分相关
    mapping(address => uint256) public userPoints;           // 用户总积分
    mapping(address => uint256) public userLastClaimTime;    // 用户最后领取积分时间

    // =============================== 事件 ==============================
    event SupportedTokenAdded(address indexed token, uint8 decimals);
    event SupportedTokenRemoved(address indexed token);
    event SetStakeAssetCap(uint256 oldTotalStakingCap, uint256 newTotalStakingCap);
    event SetOperator(address oldOperator, address newOperator);
    event SetOnlyAllowStake(bool onlyAllowStake);
    event FeeCollected(uint256 amount);

    event Stake(address indexed user, address indexed token, uint256 amount);
    event UnstakeRequest(address indexed user, uint256 amount, uint8 slot);
    event ClaimSlot(address indexed user, uint256 amount, uint8 slot);
    event ClaimAll(address indexed user, uint256 amount);
    event UnstakeInstant(address indexed user, uint256 amount);
    event AdminWithdraw(address indexed owner, uint256 amount);
    event AdminDeposit(address indexed owner, uint256 amount);
    event PointsClaimed(address indexed user, uint256 points);

    // ======================= 修饰符 ======================
    modifier onlyOperator {
        require(_msgSender() == operator, "BossFi: caller is not the operator");
        _;
    }

    modifier allowUnstakeOrClaim {
        require(!onlyAllowStake, "BossFi: only allow stake at first");
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token], "BossFi: unsupported token");
        _;
    }

    /**
     * @dev 构造函数
     */
    constructor(address _receiptTokenAddress, address _operator) Ownable() {
        receiptToken = BossFiReceiptToken(_receiptTokenAddress);
        operator = _operator;
        onlyAllowStake = true;
        totalStakingCap = type(uint256).max; // 默认无上限
    }

    // ========================== 工具函数 ==========================
    function _getPeriod() public virtual pure returns (uint256) {
        return 1 days;
    }

    function _getDateSlot(uint256 timestamp) public pure returns (uint8) {
        return uint8((timestamp + 8 hours) / _getPeriod() % MAX_DATE_SLOT);   // UTC+8 时区
    }

    function _adjustAmount(uint256 amount, uint8 decimals) public pure returns (uint256) {
        return decimals == 8 ? amount : amount * 10 ** (decimals - 8);
    }

    function _calculatePoints(uint256 amount, uint256 timeElapsed) public pure returns (uint256) {
        return (amount * timeElapsed * POINTS_PER_SATOSHI_PER_DAY) / 1 days;
    }

    // ========================== 管理员函数 ==========================
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev 添加支持的代币
     */
    function addSupportedToken(address token, uint8 decimals) public onlyOwner {
        require(token != address(0), "BossFi: invalid token address");
        require(decimals >= 8, "BossFi: decimals must be >= 8");
        
        supportedTokens[token] = true;
        tokenDecimals[token] = decimals;
        emit SupportedTokenAdded(token, decimals);
    }

    /**
     * @dev 移除支持的代币
     */
    function removeSupportedToken(address token) public onlyOwner {
        supportedTokens[token] = false;
        emit SupportedTokenRemoved(token);
    }

    function setStakeAssetCap(uint256 newTotalStakingCap) public onlyOwner {
        require(newTotalStakingCap >= totalStakingAmount, "BossFi: staking cap too small");
        emit SetStakeAssetCap(totalStakingCap, newTotalStakingCap);
        totalStakingCap = newTotalStakingCap;
    }

    function setOperator(address newOperator) public onlyOwner {
        emit SetOperator(operator, newOperator);
        operator = newOperator;
    }

    function setOnlyAllowStake(bool _onlyAllowStake) public onlyOwner {
        emit SetOnlyAllowStake(_onlyAllowStake);
        onlyAllowStake = _onlyAllowStake;
    }

    function collectFee() public onlyOwner {
        uint256 oldCollectedFee = collectedFee;
        collectedFee = 0;
        emit FeeCollected(oldCollectedFee);
    }

    // ========================= 操作员函数 ========================
    function withdraw() public onlyOperator {
        require(pendingStakeAmount > 0, "BossFi: no pending stake amount");

        uint256 oldPendingStakeAmount = pendingStakeAmount;
        pendingStakeAmount = 0;
        emit AdminWithdraw(_msgSender(), oldPendingStakeAmount);
    }

    function deposit(uint256 amount) public onlyOperator {
        require(amount > 0, "BossFi: amount should be greater than 0");

        totalClaimableAmount += amount;
        emit AdminDeposit(_msgSender(), amount);
    }

    function withdrawAndDeposit(uint256 depositAmount) public onlyOperator {
        uint256 oldPendingStakeAmount = pendingStakeAmount;
        pendingStakeAmount = 0;
        totalClaimableAmount += depositAmount;

        emit AdminWithdraw(_msgSender(), oldPendingStakeAmount);
        emit AdminDeposit(_msgSender(), depositAmount);
    }

    // =========================== 用户函数 ==========================
    /**
     * @dev 质押代币
     */
    function stake(address token, uint256 amount) public whenNotPaused validToken(token) {
        require(amount >= MIN_STAKE_AMOUNT, "BossFi: amount below minimum");
        require(
            totalStakingAmount + amount <= totalStakingCap,
            "BossFi: exceed staking cap"
        );

        uint8 decimals = tokenDecimals[token];
        uint256 adjustedAmount = _adjustAmount(amount, decimals);

        totalStakingAmount += amount;
        pendingStakeAmount += amount;

        // 更新用户积分
        _updateUserPoints(_msgSender());

        emit Stake(_msgSender(), token, amount);

        IERC20(token).safeTransferFrom(_msgSender(), address(this), adjustedAmount);
        receiptToken.mint(_msgSender(), amount);
        if (userLastClaimTime[_msgSender()] == 0) {
            userLastClaimTime[_msgSender()] = block.timestamp;
        }
    }

    /**
     * @dev 请求解质押
     */
    function unstakeRequest(uint256 amount) public whenNotPaused allowUnstakeOrClaim {
        address user = _msgSender();
        uint8 slot = _getDateSlot(block.timestamp);

        require(amount > 0, "BossFi: amount should be greater than 0");
        require(
            block.timestamp - pendingUnstakeTime[user][slot] < _getPeriod()
            || pendingUnstakeAmount[user][slot] == 0, 
            "BossFi: claim the previous unstake first"
        );

        pendingUnstakeTime[user][slot] = block.timestamp;
        pendingUnstakeAmount[user][slot] += amount;
        totalStakingAmount -= amount;
        totalRequestedAmount += amount;

        emit UnstakeRequest(user, amount, slot);

        receiptToken.burn(user, amount);
    }

    /**
     * @dev 领取指定槽位的解质押
     */
    function claimSlot(uint8 slot) public whenNotPaused allowUnstakeOrClaim {
        address user = _msgSender();
        uint256 amount = pendingUnstakeAmount[user][slot];
        uint256 fee = amount * NORMAL_UNSTAKE_FEE / 10000;

        require(amount > 0, "BossFi: no pending unstake");
        require(
            block.timestamp - pendingUnstakeTime[user][slot] >= (MAX_DATE_SLOT - 1) * _getPeriod(),
            "BossFi: haven't reached the claimable time"
        );

        pendingUnstakeAmount[user][slot] = 0;
        totalClaimableAmount -= amount;
        totalRequestedAmount -= amount;
        collectedFee += fee;

        emit ClaimSlot(user, amount, slot);
    }

    /**
     * @dev 领取所有可领取的解质押
     */
    function claimAll() public whenNotPaused allowUnstakeOrClaim {
        address user = _msgSender();
        uint256 totalAmount = 0;
        uint256 pendingCount = 0;

        for(uint8 slot = 0; slot < MAX_DATE_SLOT; slot++) {
            uint256 amount = pendingUnstakeAmount[user][slot];
            bool readyToClaim = block.timestamp - pendingUnstakeTime[user][slot] >= (MAX_DATE_SLOT - 1) * _getPeriod();
            if (amount > 0) {
                pendingCount += 1;
                if (readyToClaim) {
                    totalAmount += amount;
                    pendingUnstakeAmount[user][slot] = 0;
                }
            }
        }
        uint256 fee = totalAmount * NORMAL_UNSTAKE_FEE / 10000;

        require(pendingCount > 0, "BossFi: no pending unstake");   
        require(totalAmount > 0, "BossFi: haven't reached the claimable time");

        totalClaimableAmount -= totalAmount;
        totalRequestedAmount -= totalAmount;
        collectedFee += fee;

        emit ClaimAll(user, totalAmount);
    }

    /**
     * @dev 即时解质押
     */
    function unstakeInstant(uint256 amount) public whenNotPaused allowUnstakeOrClaim {
        address user = _msgSender();
        uint256 fee = amount * INSTANT_UNSTAKE_FEE / 10000;

        require(amount > 0, "BossFi: amount should be greater than 0");
        require(amount <= pendingStakeAmount, "BossFi: insufficient pending stake amount");

        totalStakingAmount -= amount;
        pendingStakeAmount -= amount;
        collectedFee += fee;

        emit UnstakeInstant(user, amount);

        receiptToken.burn(user, amount);
    }

    /**
     * @dev 领取积分
     */
    function claimPoints() public whenNotPaused {
        address user = _msgSender();
        uint256 points = _calculatePendingPoints(user);
        require(points > 0, "BossFi: no points to claim");

        userPoints[user] += points;
        userLastClaimTime[user] = block.timestamp;

        emit PointsClaimed(user, points);
    }

    // =========================== 查询函数 ==========================
    /**
     * @dev 计算用户待领取积分
     */
    function _calculatePendingPoints(address user) internal view returns (uint256) {
        uint256 lastClaimTime = userLastClaimTime[user];
        if (lastClaimTime == 0) return 0;

        uint256 timeElapsed = block.timestamp - lastClaimTime;
        return _calculatePoints(receiptToken.balanceOf(user), timeElapsed);
    }

    /**
     * @dev 更新用户积分
     */
    function _updateUserPoints(address user) internal {
        uint256 points = _calculatePendingPoints(user);
        if (points > 0) {
            userPoints[user] += points;
            userLastClaimTime[user] = block.timestamp;
        }
    }

    /**
     * @dev 获取用户质押信息
     */
    function getUserInfo(address user) external view returns (
        uint256 receiptBalance,
        uint256 totalPoints,
        uint256 pendingPoints,
        uint256 lastClaimTime
    ) {
        return (
            receiptToken.balanceOf(user),
            userPoints[user],
            _calculatePendingPoints(user),
            userLastClaimTime[user]
        );
    }

    /**
     * @dev 获取用户解质押请求信息
     */
    function getUserUnstakeInfo(address user, uint8 slot) external view returns (
        uint256 amount,
        uint256 requestTime,
        bool readyToClaim
    ) {
        amount = pendingUnstakeAmount[user][slot];
        requestTime = pendingUnstakeTime[user][slot];
        readyToClaim = block.timestamp - requestTime >= (MAX_DATE_SLOT - 1) * _getPeriod();
    }
}
