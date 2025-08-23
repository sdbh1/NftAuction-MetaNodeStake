// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract NftAuctionFactory is Initializable, ERC721Holder, ReentrancyGuardUpgradeable {
	address[] public auctions;

	// 拍卖ID => 拍卖合约地址
	mapping(uint256 auctionId => address) public auctionMap;

	event AuctionCreated(address auctionAddress, uint256 tokenId, uint256 auctionId);

	address[] public tokenAddresses;

	address[] public priceFeedAddresses;

	uint256 public nextAuctionId;

	modifier onlyOwner() {
		require(msg.sender == owner, "Not owner");
		_;
	}
	address owner;

	function initialize(address _owner) public initializer {
		require(_owner != address(0), "Invalid _owner address");
		__ReentrancyGuard_init();
		owner = _owner; // 工厂合约作为所有者
		nextAuctionId = 0;
	}

	// Create a new auction
	function createAuction(
		uint256 duration,
		uint256 startPrice,
		address nftContractAddress,
		uint256 tokenId
	) external returns (uint256) {
		// 先转移NFT到工厂合约
		IERC721(nftContractAddress).safeTransferFrom(msg.sender, address(this), tokenId);
		// 创建拍卖合约
		NftAuction auction = new NftAuction(address(this));

		auction.setPriceFeed(tokenAddresses, priceFeedAddresses);
		uint256 curAuctionID = nextAuctionId;

		auction.createAuction(
			curAuctionID,
			duration,
			startPrice,
			nftContractAddress,
			tokenId,
			msg.sender
		);
		auctions.push(address(auction));
		auctionMap[curAuctionID] = address(auction);
		nextAuctionId++;
		//再赋予拍卖合约操作NFT的权限
		IERC721(nftContractAddress).approve(address(auction), tokenId);

		emit AuctionCreated(address(auction), tokenId, curAuctionID);
		return curAuctionID;
	}

	function getAuctions() external view returns (address[] memory) {
		return auctions;
	}

	function getAuction(uint256 auctionId) external view returns (address) {
		address auctionAddress = address(auctionMap[auctionId]);
		require(auctionAddress != address(0), "Auction not found for this tokenId");
		return auctionAddress;
	}

	function endAuction(uint256 auctionId) external {
		address auctionAddress = auctionMap[auctionId];
		require(auctionAddress != address(0), "Auction not found for this auctionId");
		NftAuction auction = NftAuction(payable(auctionAddress));
		auction.endAuction(auctionId);
	}

	/**
	 * @dev 设置预言机地址（只能由工厂合约调用）
	 * @param _tokenAddresses 代币地址数组
	 * @param _priceFeedAddresses 对应的预言机地址数组
	 */
	function setPriceFeed(
		address[] memory _tokenAddresses,
		address[] memory _priceFeedAddresses
	) external onlyOwner {
		if (_tokenAddresses.length != _priceFeedAddresses.length) {
			revert("Array length mismatch");
		}
		priceFeedAddresses = _priceFeedAddresses;
		tokenAddresses = _tokenAddresses;
	}

	function getTokenAddresses() external view returns (address[] memory) {
		return tokenAddresses;
	}

	function getPriceFeedAddresses() external view returns (address[] memory) {
		return priceFeedAddresses;
	}
}
