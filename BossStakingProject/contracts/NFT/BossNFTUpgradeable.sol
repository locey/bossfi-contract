// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract BossNFTUpgradeable is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    // 铸造状态变量
    bool public mintingEnabled;

    // 存储每个 NFT 的 URI
    mapping(uint256 => string) private _tokenURIs;
    
    // 存储所有 tokenID
    uint256[] private _allTokenIds;

    // 添加事件
    event MintingStatusChanged(bool oldStatus, bool newStatus);
    event NFTMinted(address indexed to, uint256 tokenId, string tokenURI);
    event TokenURIUpdated(uint256 indexed tokenId, string tokenURI);

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init();
        mintingEnabled = true;
    }

    // 重写 tokenURI 方法
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // 设置 tokenURI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(_exists(tokenId), "NFT does not exist");
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner or approved");
        _tokenURIs[tokenId] = _tokenURI;
        emit TokenURIUpdated(tokenId, _tokenURI);
    }

    // 铸造 NFT
    function mint(string memory tokenURI_) public {
        require(mintingEnabled, "Minting is not enabled");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _tokenURIs[tokenId] = tokenURI_;
        _allTokenIds.push(tokenId);
        emit NFTMinted(msg.sender, tokenId, tokenURI_);
    }

    // 批量铸造
    function mintBatch(string[] memory tokenURIs) public {
        require(mintingEnabled, "Minting is not enabled");
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(msg.sender, tokenId);
            _tokenURIs[tokenId] = tokenURIs[i];
            _allTokenIds.push(tokenId);
            emit NFTMinted(msg.sender, tokenId, tokenURIs[i]);
        }
    }

    // 获取所有 tokenID 和对应的 URI
    function getAllTokenURIs() public view returns (uint256[] memory tokenIds, string[] memory uris) {
        uint256 totalTokens = _allTokenIds.length;
        tokenIds = new uint256[](totalTokens);
        uris = new string[](totalTokens);

        for (uint256 i = 0; i < totalTokens; i++) {
            uint256 tokenId = _allTokenIds[i];
            if (_exists(tokenId)) {
                tokenIds[i] = tokenId;
                uris[i] = _tokenURIs[tokenId];
            }
        }
        return (tokenIds, uris);
    }

    // 获取当前 token 总数
    function getTotalTokens() public view returns (uint256) {
        return _allTokenIds.length;
    }

    // 设置铸造状态
    function setMintingEnabled(bool _mintingEnabled) external onlyOwner {
        mintingEnabled = _mintingEnabled;
        emit MintingStatusChanged(mintingEnabled, _mintingEnabled);
    }
}