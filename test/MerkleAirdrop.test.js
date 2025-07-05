// test/MerkleAirdrop.test.js
require("@nomicfoundation/hardhat-chai-matchers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");

describe("MerkleAirdrop", function () {
  let deployer, user;
  let token, airdrop;
  let merkleRoot;
  let tree;

  // 这里的users只用address，和合约leaf一致
  const users = [
    { address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" }, // 使用测试账户地址
  ];

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockERC20");
    token = await Token.deploy("Test Token", "TEST");

    // leaf和合约保持一致：keccak256(abi.encodePacked(address))
    const leaves = users.map((u) => ethers.solidityPackedKeccak256(["address"], [u.address]));
    tree = new MerkleTree(leaves, (v) => v, { sortPairs: true });
    merkleRoot = tree.getHexRoot();

    const MerkleAirdrop = await ethers.getContractFactory("MerkleAirdrop");
    airdrop = await MerkleAirdrop.deploy(merkleRoot, await token.getAddress());
    await token.transfer(await airdrop.getAddress(), 1000);
  });

  it("should deploy and set the correct Merkle root", async function () {
    expect(await airdrop.merkleRoot()).to.equal(merkleRoot);
  });

  it("should claim tokens successfully with valid proof", async function () {
    const leaf = ethers.solidityPackedKeccak256(["address"], [users[0].address]);
    const proof = tree.getHexProof(leaf);
    await expect(airdrop.connect(user).claim(proof))
      .to.emit(airdrop, "Claimed")
      .withArgs(await user.getAddress(), 1000);
    expect(await token.balanceOf(await user.getAddress())).to.equal(1000);
  });

  it("should not allow claiming twice", async function () {
    const leaf = ethers.solidityPackedKeccak256(["address"], [users[0].address]);
    const proof = tree.getHexProof(leaf);
    await airdrop.connect(user).claim(proof);
    await expect(airdrop.connect(user).claim(proof)).to.be.revertedWith("Already claimed");
  });

  it("should allow owner to set new Merkle root", async function () {
    const newMerkleRoot = ethers.solidityPackedKeccak256(["string"], ["newMerkleRoot"]);
    await airdrop.connect(deployer).setMerkleRoot(newMerkleRoot);
    expect(await airdrop.merkleRoot()).to.equal(newMerkleRoot);
  });
});
