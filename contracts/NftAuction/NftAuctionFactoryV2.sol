// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./NftAuctionFactory.sol";

/**
 * @title NftAuctionFactoryV2
 * @dev 单个NFT拍卖合约，由NftAuctionFactory创建和管理
 */
contract NftAuctionFactoryV2 is NftAuctionFactory {
	function HelloV2() public pure returns (string memory) {
		return "NftAuctionFactoryV2 Hello V2";
	}
}
