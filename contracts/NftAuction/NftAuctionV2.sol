// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NftAuction.sol";

/**
 * @title NftAuctionV2
 * @dev 单个NFT拍卖合约，由NftAuctionFactory创建和管理 
 */
contract NftAuctionV2 is NftAuction {
	function HelloV2() public pure returns (string memory) {
		return "NftAuctionV2 Hello V2";
	}
}
