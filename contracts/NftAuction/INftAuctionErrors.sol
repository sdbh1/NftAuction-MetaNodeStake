// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

/**
 * @dev Standard NftAuction Errors
 * @dev NFT拍卖标准错误定义
 */
interface INftAuctionErrors {
    /**
     * @dev Indicates an error when the auction is not exist.
     * @dev 拍卖不存在时的错误
     */
    error AuctionNotExist();
    
    /**
     * @dev Indicates an error when array lengths don't match in batch operations.
     * @dev 批量操作时数组长度不匹配的错误
     * @param tokenAddressesLength Length of the token addresses array.
     * @param priceFeedAddressesLength Length of the price feed addresses array.
     */
	error ArrayLengthMismatch(uint256 tokenAddressesLength, uint256 priceFeedAddressesLength);

    /**
     * @dev Indicates an error when no price feed is configured for a token.
     * @dev 代币没有配置价格预言机时的错误
     * @param tokenAddress Address of the token that lacks price feed support.
     */
	error NoSupportedPriceFeed(address tokenAddress);

    /**
     * @dev Indicates an error when bid price is not high enough to win the auction.
     * @dev 出价不够高无法赢得拍卖时的错误
     * @param bidPrice The current bid price offered.
     * @param highestPrice The current highest bid price that needs to be exceeded.
     */
	error BidPriceNoHighEnough(uint256 bidPrice, uint256 highestPrice);

    // 注意：部分错误已改为使用字符串消息以简化处理

}

