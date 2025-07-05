// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MerkleAirdrop is Ownable {
    bytes32 public merkleRoot;
    IERC20 public immutable token;

    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed user, uint256 amount);

    constructor(bytes32 _merkleRoot, address _token) {
        merkleRoot = _merkleRoot;
        token = IERC20(_token);
    }

    function claim(bytes32[] calldata proof) external {
        require(!hasClaimed[msg.sender], "Already claimed");
        hasClaimed[msg.sender] = true;

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
        
        uint256 amount = token.balanceOf(address(this)); // Take all the tokens from the contract
        require(
            token.transfer(msg.sender, amount),
            "Transfer failed"
        );

        emit Claimed(msg.sender, amount);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(
            token.transfer(to, amount),
            "Withdrawal failed"
        );
    }
}
