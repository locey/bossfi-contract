// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BossToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public minter;

    event MinterChanged(address indexed previousMinter, address indexed newMinter);

    function initialize() public initializer {
        __ERC20_init("Boss Token", "BOSS");
        __Ownable_init();
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Caller is not the minter");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Invalid minter address");
        emit MinterChanged(minter, _minter);
        minter = _minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyMinter {
        _burn(msg.sender, amount);
    }
}
