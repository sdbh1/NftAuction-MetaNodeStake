// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {INftAuctionErrors} from "./INftAuctionErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

/**
 * @title NftAuction
 * @dev 单个NFT拍卖合约，由NftAuctionFactory创建和管理
 */
contract NftAuction is
    ERC721Holder,
    ReentrancyGuard,
    Ownable,
    INftAuctionErrors
{
    //结构体
    struct Auction {
        uint256 auctionId;
        //卖家
        address seller;
        // 拍卖持续时间
        uint256 duration;
        // 开始时间
        uint256 startTime;
        //是否结束
        bool ended;
        // 最高出价者
        address hightestBidder;
        // 最高价格
        uint256 highestBid;
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 tokenId;
        // 参与竞价的资产类型 0x 地址表示eth，其他地址表示erc20
        // 0x0000000000000000000000000000000000000000 表示eth
        address tokenAddress;
        // 参与竞价的代币数量
        uint256 tokenCount;
    }

    // ============ 状态变量 ============

    /// @dev 拍卖信息（此合约只管理一个拍卖）
    Auction public auction;

    /// @dev 代币合约地址=>预言机地址
    mapping(address => AggregatorV3Interface) public dataFeeds;

    // ============ 事件 ============

    event BidPlaced(
        uint256 indexed auctionId,
        address tokenAddress,
        uint256 amount,
        address indexed higherBidder,
        uint256 highestPrice
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice,
        bool hasWinner
    );

    // ============ 初始化函数 ============

    /**
     * @dev 初始化拍卖合约
     */
    constructor(address _owner) Ownable(_owner) ReentrancyGuard() {
    }

    // ============ 外部函数 ============

    /**
     * @dev 创建拍卖（只能由工厂合约调用）
     * @param _duration 拍卖持续时间（秒）
     * @param _startPrice 起拍价格（USD，8位小数）
     * @param _nftAddress NFT合约地址
     * @param _tokenId NFT Token ID
     * @param _seller 卖家地址
     */
    function createAuction(
        uint256 _auctionId,
        uint256 _duration,
        uint256 _startPrice,
        address _nftAddress,
        uint256 _tokenId,
        address _seller
    ) external onlyOwner {
        // 检查参数
        // require(_duration >= 60, "Duration must be at least 60 seconds"); // 最少1分钟
        // require(_duration <= 30 days, "Duration cannot exceed 30 days"); // 最多30天
        require(_startPrice > 0, "Start price must be greater than 0");
        require(_nftAddress != address(0), "Invalid NFT contract address");
        require(_seller != address(0), "Invalid seller address");


        // 验证NFT所有权（应该已经转移到工厂合约）
        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == owner(),
            "NFT not owned by factory"
        );

        // 创建拍卖
        auction = Auction({
            auctionId: _auctionId,
            seller: _seller,
            duration: _duration,
            ended: false,
            hightestBidder: address(0),
            highestBid: _startPrice,
            startTime: block.timestamp,
            nftContract: _nftAddress,
            tokenId: _tokenId,
            tokenAddress: address(0), // 初始为ETH
            tokenCount: 0
        });
    }

    /**
     * @dev 参与竞价
     * @param _auctionID 拍卖ID
     * @param _tokenAddress 竞价代币地址（address(0)表示ETH）
     * @param _amount 竞价代币数量
     */
    function placeBid(
        uint256 _auctionID,
        address _tokenAddress,
        uint256 _amount
    ) external payable nonReentrant {
        if (auction.startTime == 0) {
            revert("Auction does not exist");
        }

        // 检查拍卖是否已经结束
        if (
            auction.ended ||
            auction.startTime + auction.duration <= block.timestamp
        ) {
            revert("Auction has already ended");
        }

        // 检查竞价者不能是卖家
        require(
            msg.sender != auction.seller,
            "Seller cannot bid on own auction"
        );

        // 验证ETH和ERC20的一致性
        if (_tokenAddress == address(0)) {
            require(msg.value == _amount, "ETH amount mismatch");
            require(_amount > 0, "ETH amount must be greater than 0");
        } else {
            require(msg.value == 0, "Should not send ETH for ERC20 bid");
            require(_amount > 0, "Token amount must be greater than 0");
        }

        // 根据预言机获得基于USD的最新价格
        uint256 currentBid = getPriceBaseUSD(_tokenAddress, _amount);
        uint256 highestPrice = auction.highestBid; // 直接使用USD价格比较

        // 后续竞价需要超过当前最高价
        if (currentBid <= highestPrice) {
            revert("Bid price is not high enough");
        }

        // 退还前一个竞价者的资金
        _refundPreviousBidder();

        // 转移新的竞价资金到合约
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        // ETH已经通过msg.value转移

        // 更新拍卖信息
        auction.highestBid = currentBid;
        auction.hightestBidder = msg.sender;
        auction.tokenAddress = _tokenAddress;
        auction.tokenCount = _amount;
        // 发出竞价事件
        emit BidPlaced(
            _auctionID,
            _tokenAddress,
            _amount,
            auction.hightestBidder,
            auction.highestBid
        );
    }

    // ============ 内部函数 ============

    /**
     * @dev 退还前一个竞价者的资金
     */
    function _refundPreviousBidder() internal {
        if (auction.hightestBidder == address(0)) {
            return; // 没有前一个竞价者
        }

        address previousBidder = auction.hightestBidder;
        address tokenAddress = auction.tokenAddress;
        uint256 amount = auction.tokenCount;

        if (tokenAddress == address(0)) {
            // 退还ETH
            (bool success, ) = payable(previousBidder).call{value: amount}("");
            require(success, "ETH refund failed");
        } else {
            // 退还ERC20代币
            IERC20(tokenAddress).transfer(previousBidder, amount);
        }
    }

    // ============ 查询函数 ============

    /**
     * @dev 根据代币地址和数量获得基于USD的价格
     * @param tokenAddress 代币地址（address(0)表示ETH）
     * @param amount 代币数量
     * @return price USD价格（8位小数）
     */
    function getPriceBaseUSD(address tokenAddress, uint256 amount)
        public
        view
        returns (uint256)
    {
        int256 pricePerToken = getChainlinkDataFeedLatestAnswer(tokenAddress);
        if (pricePerToken <= 0) {
        	revert("Invalid price feed data");
        }

        // 计算总价值：(代币数量 * 单价) / 10^8
        // 注意：Chainlink价格通常是8位小数
        uint256 totalValue = (uint256(pricePerToken) * amount) / 1e8;
        return totalValue;
    }

    /**
     * @dev 设置预言机地址（只能由工厂合约调用）
     * @param tokenAddresses 代币地址数组
     * @param priceFeedAddresses 对应的预言机地址数组
     */
    function setPriceFeed(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    ) external onlyOwner {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert("Array length mismatch");
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            // require(tokenAddresses[i] != address(0), "Invalid token address");
            require(
                priceFeedAddresses[i] != address(0),
                "Invalid price feed address"
            );
            dataFeeds[tokenAddresses[i]] = AggregatorV3Interface(
                priceFeedAddresses[i]
            );
        }
    }

    /**
     * @dev 获取Chainlink预言机的最新价格
     * @param tokenAddress 代币地址
     * @return 最新价格（8位小数）
     */
    function getChainlinkDataFeedLatestAnswer(address tokenAddress)
        public
        view
        returns (int256)
    {
        AggregatorV3Interface dataFeed = dataFeeds[tokenAddress];

        // 检查是否设置了对应的预言机地址
        if (address(dataFeed) == address(0)) {
            revert("No supported price feed for this token");
        }

        (
            ,
            /* uint80 roundId */
            int256 answer, /*uint256 startedAt*/ /*uint256 updatedAt*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = dataFeed.latestRoundData();
        return answer;
    }

    /**
     * @dev 结束拍卖，将NFT转移给最高竞价者或退回给卖家
     * @param _auctionID 拍卖ID
     */
    function endAuction(uint256 _auctionID) external onlyOwner nonReentrant {
        // 检查拍卖是否存在
        if (auction.startTime == 0) {
            revert AuctionNotExist();
        }

        // 检查拍卖是否已经结束
        if (auction.ended) {
            revert("Auction has already ended");
        }

        // 检查拍卖时间是否已到
        if (auction.startTime + auction.duration > block.timestamp) {
            revert("Auction time has not ended yet");
        }

        bool hasWinner = auction.hightestBidder != address(0);
        address nftRecipient;

        if (hasWinner) {
            // 有竞价者，NFT转给最高竞价者
            nftRecipient = auction.hightestBidder;

            // 将竞价资金转给卖家（扣除可能的平台手续费）
            if (auction.tokenAddress == address(0)) {
                // ETH支付
                (bool success, ) = payable(auction.seller).call{
                    value: auction.tokenCount
                }("");
                require(success, "Payment to seller failed");
            } else {
                // ERC20支付
                IERC20(auction.tokenAddress).transfer(
                    auction.seller,
                    auction.tokenCount
                );
            }
        } else {
            // 无竞价者，NFT退回给卖家
            nftRecipient = auction.seller;
        }

        // 转移NFT
        IERC721(auction.nftContract).safeTransferFrom(
            owner(),
            nftRecipient,
            auction.tokenId
        );

        // 标记拍卖结束
        auction.ended = true;

        // 发出拍卖结束事件
        emit AuctionEnded(
            _auctionID,
            hasWinner ? auction.hightestBidder : address(0),
            hasWinner ? auction.highestBid : 0,
            hasWinner
        );
    }

    // ============ 查询函数 ============

    /**
     * @dev 获取拍卖信息
     * @return auction 拍卖详细信息
     */
    function getAuctionInfo() external view returns (Auction memory) {
        return auction;
    }

    /**
     * @dev 获取拍卖ID信息
     * @return auctionID 获取拍卖ID
     */
    function getAuctionID() external view returns (uint256 auctionID) {
        return auction.auctionId;
    }

    /**
     * @dev 检查拍卖是否已结束
     * @return 是否已结束
     */
    function isAuctionEnded() external view returns (bool) {
        return
            auction.ended ||
            (auction.startTime + auction.duration <= block.timestamp);
    }

    /**
     * @dev 获取拍卖剩余时间
     * @return 剩余时间（秒），如果已结束返回0
     */
    function getRemainingTime() external view returns (uint256) {
        if (auction.ended || auction.startTime == 0) {
            return 0;
        }

        uint256 endTime = auction.startTime + auction.duration;
        if (block.timestamp >= endTime) {
            return 0;
        }

        return endTime - block.timestamp;
    }

    /**
     * @dev 接收ETH
     */
    receive() external payable {
        // 允许接收ETH用于竞价
    }
}
