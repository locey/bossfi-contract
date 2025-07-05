// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BossFiReceiptToken
 * @dev 收据代币，代表用户在BossFi质押的比特币
 * 1 收据代币 = 1 satoshi (最小比特币单位)
 */
contract BossFiReceiptToken is ERC20, Ownable, Pausable {
    uint8 private constant DECIMALS = 8; // 与比特币相同的小数位数
    
    // 只有质押合约可以铸造和销毁代币
    address public stakingContract;
    
    event StakingContractSet(address indexed oldContract, address indexed newContract);
    
    constructor() ERC20("BossFi Bitcoin Receipt", "bBTC") Ownable() {
        _pause(); // 初始暂停状态，等待设置质押合约
    }
    
    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "BossFi: caller is not staking contract");
        _;
    }
    
    /**
     * @dev 设置质押合约地址
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "BossFi: invalid staking contract");
        emit StakingContractSet(stakingContract, _stakingContract);
        stakingContract = _stakingContract;
        _unpause(); // 设置后启用合约
    }
    
    /**
     * @dev 铸造收据代币（仅质押合约可调用）
     */
    function mint(address to, uint256 amount) external onlyStakingContract whenNotPaused {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁收据代币（仅质押合约可调用）
     */
    function burn(address from, uint256 amount) external onlyStakingContract whenNotPaused {
        _burn(from, amount);
    }
    
    /**
     * @dev 重写decimals函数
     */
    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }
    
    /**
     * @dev 暂停合约
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 重写transfer函数，添加暂停检查
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev 重写transferFrom函数，添加暂停检查
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
} 