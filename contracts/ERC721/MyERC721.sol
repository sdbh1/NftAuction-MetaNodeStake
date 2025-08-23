// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ClassicERC721
 * @dev 一个经典的ERC721非同质化代币合约示例
 * 包含基本功能：铸造、转账、授权等
 */
contract MyERC721 is ERC721, Ownable {
    /**
     * @dev Indicates a `tokenId` whose metadata is already bound.
     * @param tokenId Identifier number of a token.
     */
    error MetaDataAlreadyBound(uint256 tokenId);

    // 代币ID计数器
    uint256 internal _tokenIdCounter = 0;

    // 可选：代币元数据基础URI
    string private _baseTokenURI;

    // 可选：最大供应量
    uint256 public maxSupply;

    mapping(uint256 => string) private _tokenMetaData;

    /**
     * @dev 构造函数，初始化代币名称和符号
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param maxSupply_ 最大供应量（0表示无上限）
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        maxSupply = maxSupply_;
    }

    /**
     * @dev 设置基础元数据URI
     * @param baseTokenURI_ 新的基础URI
     */
    function setBaseURI(string memory baseTokenURI_) external onlyOwner {
        _baseTokenURI = baseTokenURI_;
    }

    /**
     * @dev 重写基础URI函数
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev 铸造新的NFT并发送给指定地址
     * @param to 接收者地址
     */
    function mint(address to) external {
        require(
            maxSupply == 0 || _tokenIdCounter < maxSupply,
            "Max supply reached"
        );

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    /**
     * @dev 绑定元数据到代币ID
     * @param tokenId 代币ID
     * @param metaDataUrl 元数据URL
     */
    function bindMetaData(uint256 tokenId, string memory metaDataUrl) external {
        require(hashCompareInternal("",metaDataUrl) == false, "Meta data url is empty");

        address owner = _ownerOf(tokenId);
        //如果这个tokenId没有被铸造过，那么就不能绑定元数据
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        //如果这个tokenId已经被绑定过元数据，那么就不能重复绑定
        if (bytes(_tokenMetaData[tokenId]).length > 0) {
            revert MetaDataAlreadyBound(tokenId);
        }
        // bind meta data to tokenId
        _tokenMetaData[tokenId] = string.concat(_baseTokenURI, metaDataUrl);
    }

    /**
     * @dev 获取当前已铸造的代币总数
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }

    function hashCompareInternal(string memory a, string memory b) internal pure  returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }   

    /**
     * @dev 重写tokenURI函数
     * @param tokenId 代币ID
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token not minted");
        return _tokenMetaData[tokenId];
    }
}
