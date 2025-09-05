const { ethers, deployments, getNamedAccounts } = require("hardhat");
const { expect } = require("chai");
const fs = require("fs");
const path = require("path");
const { error } = require("console");

let AuctionFactory;
let nftContract;
let erc20Contract;
let nftAuctionProxyV2;
let auctionContract;
const contractCachePath = path.join(__dirname, "contract-cache.json");
describe("NFT创建和创建NFT拍卖", async function () {
    this.timeout(120000);
    // 如果需要强制重新部署，可以取消下面这行的注释
    // clearContractCache();

    beforeEach(async function () {
        // 尝试从缓存加载合约
        const cachedContracts = loadContractCache();
        let useCache = false;

        if (cachedContracts) {
            try {
                // 验证缓存的合约是否有效
                console.log("🔍 验证缓存的合约地址");

                const tempNftContract = await ethers.getContractAt("MyERC721", cachedContracts.nftAddress);
                const tempAuctionContract = await ethers.getContractAt("NftAuctionFactory", cachedContracts.auctionAddress);
                const tempErc20Contract = await ethers.getContractAt("MyERC20", cachedContracts.erc20Address);

                // 尝试调用合约方法来验证合约是否有效
                await tempNftContract.getAddress();
                await tempAuctionContract.getAddress();
                await tempErc20Contract.getAddress();

                // 如果没有抛出异常，说明缓存有效
                console.log("🚀 使用缓存的合约地址");
                AuctionFactory = { address: cachedContracts.auctionAddress };
                AuctionFactory = tempAuctionContract;
                nftContract = tempNftContract;
                erc20Contract = tempErc20Contract;

                //设置预言机
                await setPriceFeed();
                console.log("tokenAddresses:", await AuctionFactory.getTokenAddresses());
                console.log("priceFeedAddresses:", await AuctionFactory.getPriceFeedAddresses());
                console.log("拍卖合约地址代理 (缓存):", await AuctionFactory.getAddress());
                console.log("拍卖合约地址 (缓存):", await AuctionFactory.getAddress());
                console.log("NFT合约地址 (缓存):", await tempNftContract.getAddress());
                console.log("ERC20合约地址 (缓存):", await tempErc20Contract.getAddress());
                useCache = true;
            } catch (error) {
                console.log("❌ 缓存的合约地址无效，将重新部署:", error.message);
            }
        }

        if (!useCache) {
            // 重新部署合约
            console.log("🔨 重新部署合约");

            //1.部署拍卖合约
            await deployments.fixture(["deployNftAuctionFactory"]);
            const AuctionFactoryProxy = await deployments.get("NftAuctionFactoryProxy");
            console.log("🔨 重新部署合约", AuctionFactoryProxy.address);
            AuctionFactory = await ethers.getContractAt("NftAuctionFactory", AuctionFactoryProxy.address);

            //2.部署NFT合约
            await deployments.fixture(["MyERC721Deploy"]);
            const dep = await deployments.get("MyERC721");
            nftContract = await ethers.getContractAt("MyERC721", dep.address);

            //3.部署ERC20合约
            await deployments.fixture(["MyERC20Deploy"]);
            const erc20Dep = await deployments.get("MyERC20");
            erc20Contract = await ethers.getContractAt("MyERC20", erc20Dep.address);

            console.log("拍卖合约地址 (新部署):", await AuctionFactory.getAddress());
            console.log("NFT合约地址 (新部署):", dep.address);
            console.log("ERC20合约地址 (新部署):", erc20Dep.address);
            //设置预言机
            await setPriceFeed();
            console.log("tokenAddresses:", await AuctionFactory.getTokenAddresses());
            console.log("priceFeedAddresses:", await AuctionFactory.getPriceFeedAddresses());
            // 保存到缓存
            saveContractCache({
                auctionAddress: await AuctionFactory.getAddress(),
                nftAddress: dep.address,
                erc20Address: erc20Dep.address,
                timestamp: new Date().toISOString()
            });
        }
    })
    describe("创建拍卖", async function () {
        it("检查拍卖号是否重复", async function () {
            let res1 = await createAuction(100)
            let res2 = await createAuction(100)
            const auction1 = await ethers.getContractAt("NftAuction", res1.auctionAddress);
            const auction2 = await ethers.getContractAt("NftAuction", res2.auctionAddress);
            let aId1 = await auction1.getAuctionID();
            let aId2 = await auction2.getAuctionID();
            expect(aId1).to.not.equal(aId2);
            expect(res1.auctionId).to.not.equal(res2.auctionId);
        })
        it("如果是测试网,则设置预言机", async function () {
            // 检查当前网络
            const network = await ethers.provider.getNetwork();
            if (network.chainId === 31337n) {
                console.log("⚠️  本地网络无法测试 Chainlink 预言机，跳过此设置");
                this.skip();
            }
            await setPriceFeed();
            const priceFeeds1 = await AuctionFactory.getChainlinkDataFeedLatestAnswer(tokenAddresses[0]) / 1e8;
            const priceFeeds2 = await AuctionFactory.getChainlinkDataFeedLatestAnswer(tokenAddresses[1]) / 1e8;
            const priceFeeds3 = await AuctionFactory.getChainlinkDataFeedLatestAnswer(tokenAddresses[2]) / 1e8;
            const dataFeeds1 = await AuctionFactory.dataFeeds(tokenAddresses[0]) / 1e8;
            const dataFeeds2 = await AuctionFactory.dataFeeds(tokenAddresses[1]) / 1e8;
            const dataFeeds3 = await AuctionFactory.dataFeeds(tokenAddresses[2]) / 1e8;

            expect(dataFeeds1).to.equal(priceFeedAddresses[0]);
            expect(dataFeeds2).to.equal(priceFeedAddresses[1]);
            expect(dataFeeds3).to.equal(priceFeedAddresses[2]);

            expect(priceFeeds1).to.not.equal(0);
            expect(priceFeeds2).to.not.equal(0);
            expect(priceFeeds3).to.not.equal(0);

            console.log("ETH/USD priceFeeds:", priceFeeds1);
            console.log("BTC/USD priceFeeds:", priceFeeds2);
            console.log("USDC/USD priceFeeds:", priceFeeds3);
        })
    })

    describe("竞拍拍卖", async function () {
        it("使用USDC和ETH混合竞拍,并且正确计价", async function () {
            if (await isLocalHostNet()) {
                console.log("isLocalNet:", isLocalHostNet());
                this.skip();
                return;
            }
            let auctionResult = await createAuction(60)

            //nft所有权应该在工厂合约上
            let nftOwner = await nftContract.ownerOf(auctionResult.tokenId);
            expect(nftOwner).to.equal(await AuctionFactory.getAddress());

            let tokenId = auctionResult.tokenId; // 从返回的对象中提取tokenId
            auctionContract = await ethers.getContractAt("NftAuction", auctionResult.auctionAddress);
            //1.获得当前部署的账户
            const [deployer, user1, user2] = await ethers.getSigners();
            console.log("开始竞拍...");
            //通过IERC20合约地址，获得一个合约对象
            let i20Address = isLocalHostNet() ? await erc20Contract.getAddress() : tokenAddresses[2];
            console.log("i20Address:", i20Address);
            if (await isLocalHostNet()) {
                console.log("isLocalNet:", isLocalHostNet());
                this.skip();
                return;
            }
            let erc20Instance = isLocalHostNet() ? erc20Contract : await ethers.getContractAt("IERC20", i20Address);
            // 创建ERC20合约实例
            if (await isLocalHostNet()) {
                await erc20Instance.mint(deployer.address, 10);
            }

            let decimals = await erc20Instance.decimals();
            console.log("拍卖行合约地址:", await AuctionFactory.getAddress());
            let pidResult = true;
            try {
                // 抽取事件监听函数
                // USER1 使用1个ETH 参加竞拍
                let tx = await auctionContract.connect(user1).placeBid(tokenId, ethers.ZeroAddress, ethers.parseEther("0.0001"), {
                    value: ethers.parseEther("0.0001") // 发送1 ETH  
                });
                let receipt = await tx.wait();
                logBidPlacedEvent(receipt, "第一次竞价事件");
                let _ercAmount = 1n;
                // deployer 使用10个USDC 参加竞拍
                await erc20Instance.connect(deployer).approve(auctionResult.auctionAddress, _ercAmount * (10n ** BigInt(decimals)));
                tx = await auctionContract.connect(deployer).placeBid(tokenId, await erc20Contract.getAddress(), _ercAmount * (10n ** BigInt(decimals)));
                receipt = await tx.wait();

                logBidPlacedEvent(receipt, "第二次竞价事件");
            } catch (error) {
                console.log("竞价失败:", error);
                pidResult = false;
            }
            expect(pidResult).to.equal(true);
        })

        it("检查出价是否正确", async function () {
            let auctionResult = await createAuction(60)
            auctionContract = await ethers.getContractAt("NftAuction", auctionResult.auctionAddress);
            let auctionData = await auctionContract.auction();
            expect(auctionData.highestBid).to.equal(ethers.parseEther("0.00001"));
        })

        it("检查是否可以创建低于当前价格的拍卖", async function () {
            const [deployer, user1, user2] = await ethers.getSigners();
            let auctionResult = await createAuction(60)
            let tokenId = auctionResult.tokenId; // 从返回的对象中提取tokenId
            auctionContract = await ethers.getContractAt("NftAuction", auctionResult.auctionAddress);
            let result = false;
            try {
                let tx = await auctionContract.connect(user1).placeBid(tokenId, ethers.ZeroAddress, ethers.parseEther("0.000001"), {
                    value: ethers.parseEther("0.000001")
                });
                let receipt = await tx.wait();
                logBidPlacedEvent(receipt, "第一次竞价事件");
            } catch (error) {
                console.log("创建低于当前价格的拍卖失败:", error.message);
                expect(error.message).to.include("Bid price is not high enough");
                //只有返回错误才能通过
                result = true;
            }
            expect(result).to.equal(true);
        })

    })

    describe("结束拍卖", async function () {
        it("提前结束,应该返回错误", async function () {
            let auctionResult = await createAuction(30)
            console.log("开始结束拍卖...");
            let endResult = false;
            try {
                await AuctionFactory.endAuction(auctionResult.auctionId);
            } catch (error) {
                console.log("提前结束失败:", error);
                endResult = true;
            }
            console.log("结束拍卖...");
            expect(endResult).to.equal(true);
        })

        it("有出价者,最终应转移到最高出价人", async function () {
            let auctionResult = await createAuction(30)
            let tokenId = auctionResult.tokenId; // 从返回的对象中提取tokenId
            auctionContract = await ethers.getContractAt("NftAuction", auctionResult.auctionAddress);
            //1.获得当前部署的账户
            const [deployer, user1, user2] = await ethers.getSigners();
            //2.竞拍
            console.log("开始竞拍...");
            console.log("拍卖行合约地址:", await AuctionFactory.getAddress());
            // 在竞拍时直接发送ETH
            let tx = await auctionContract.connect(user1).placeBid(tokenId, ethers.ZeroAddress, ethers.parseEther("0.0001"), {
                value: ethers.parseEther("0.0001") // 发送1 ETH  
            });
            await tx.wait(); // 等待交易确认
            // 在竞拍时直接发送ETH
            tx = await auctionContract.connect(deployer).placeBid(tokenId, ethers.ZeroAddress, ethers.parseEther("0.0002"), {
                value: ethers.parseEther("0.0002") // 发送1 ETH  
            });
            await tx.wait(); // 等待交易确认
            //4.检查是否有出价者
            console.log("竞拍交易完成");
            const auctionData = await auctionContract.auction();
            const hasBidder = auctionData.hightestBidder != ethers.ZeroAddress;
            console.log("竞拍交易完成 highestBidder:", auctionData.hightestBidder);
            expect(hasBidder).to.be.true;
            //等待30秒
            await new Promise(resolve => setTimeout(resolve, 10000));
            console.log("已等待10秒剩余20秒");

            await new Promise(resolve => setTimeout(resolve, 10000));
            console.log("已等待10秒剩余10秒");

            await new Promise(resolve => setTimeout(resolve, 10000));
            //结束竞拍
            console.log("开始结束拍卖...");
            await AuctionFactory.endAuction(tokenId);
            //5.检查是否转移到最高出价人
            // 重新获取最新的拍卖数据进行验证
            const finalAuctionData = await auctionContract.auction();
            expect(finalAuctionData.hightestBidder).to.equal(deployer.address);
            //检查nft是否转移到最高出价人
            expect(await nftContract.ownerOf(tokenId)).to.equal(deployer.address);
        })

        it("无人竞拍,nft应返回原主人", async function () {
            let auctionResult = await createAuction(1)
            //等待10秒
            await new Promise(resolve => setTimeout(resolve, 11000));
            //结束竞拍
            console.log("开始结束拍卖...");
            await AuctionFactory.endAuction(auctionResult.auctionId);
            console.log("结束拍卖...");
            //检查是否转移到卖家
            const [deployer, user1, user2] = await ethers.getSigners();
            console.log("nft合约地址:", await nftContract.ownerOf(auctionResult.tokenId));
            expect(await nftContract.ownerOf(auctionResult.tokenId)).to.not.equal(deployer.address);
            expect(await nftContract.ownerOf(auctionResult.tokenId)).to.equal(user2.address);
        })
    })
})

async function createAuction(_during) {
    //1.获得当前部署的账户
    const [deployer, user1, user2] = await ethers.getSigners();
    let totalSupply = await nftContract.totalSupply()
    console.log("开始等待创建nft成功")
    const tx = await nftContract.mint(user2.address);
    await tx.wait();
    totalSupply = await nftContract.totalSupply();
    let tokenId = totalSupply - 1n;

    console.log("创建nft成功 tokenID =  ", tokenId);

    const approveTx = await nftContract.connect(user2).approve(await AuctionFactory.getAddress(), tokenId);
    await approveTx.wait(); // 等待授权交易确认
    console.log("NFT授权完成，Token ID:", tokenId.toString());

    // 验证授权状态
    const approvedAddress = await nftContract.getApproved(tokenId);
    const factoryAddress = await AuctionFactory.getAddress();
    console.log("授权地址:", approvedAddress);
    console.log("工厂地址:", factoryAddress);
    if (approvedAddress.toLowerCase() !== factoryAddress.toLowerCase()) {
        throw new Error(`授权失败: 期望 ${factoryAddress}, 实际 ${approvedAddress}`);
    }

    //2.创建拍卖
    console.log("开始创建拍卖...");
    let nftAddres = await nftContract.getAddress();
    try {
        const createTx = await AuctionFactory.connect(user2).createAuction(
            _during,
            ethers.parseEther("0.00001"),
            nftAddres,
            tokenId,
        );
        const receipt = await createTx.wait();
        console.log("交易成功:", receipt);
        // 解析AuctionCreated事件
        const auctionCreatedEvent = receipt.logs.find(log => {
            try {
                const parsed = AuctionFactory.interface.parseLog(log);
                return parsed.name === 'AuctionCreated';
            } catch {
                return false;
            }
        });

        if (auctionCreatedEvent) {
            const parsed = AuctionFactory.interface.parseLog(auctionCreatedEvent);
            const auctionAddress = parsed.args.auctionAddress;
            const tokenId = parsed.args.tokenId;
            const auctionId = parsed.args.auctionId;

            console.log("创建拍卖成功!");
            console.log("拍卖合约地址:", auctionAddress);
            console.log("NFT Token ID:", tokenId.toString());
            console.log("拍卖 ID:", auctionId.toString());

            return { tokenId, auctionAddress, auctionId: auctionId.toString() };
        } else {
            console.log("未找到AuctionCreated事件");
            console.log("创建拍卖交易:", createTx);
            return { tokenId, auctionAddress: null, auctionId: null };
        }
    } catch (error) {
        console.log("=== 详细错误信息 ===");
        console.log("错误消息:", error.message);
        console.log("错误原因:", error.reason);
        console.log("错误代码:", error.code);
        console.log("错误数据:", error.data);

        // 如果是合约执行错误，可能包含更多信息
        if (error.error) {
            console.log("合约错误:", error.error);
        }

        // 完整的错误对象
        console.log("完整错误:", JSON.stringify(error, null, 2));
    }


}

// Sepolia网络中的所有代币地址
const tokenAddresses = [
    "0x0000000000000000000000000000000000000000", // ETH
    "0x835ef3b3d6fb94b98bf0a3f5390668e4b83731c5", // BTC 
    "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"  // USDC
];

// 对应的Chainlink价格预言机地址
const priceFeedAddresses = [
    "0x694AA1769357215DE4FAC081bf1f309aDC325306", // ETH/USD Price Feed
    "0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43", // BTC/USD Price Feed
    "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E"  // USDC/USD Price Feed
];
async function setPriceFeed() {
    // 检查当前网络
    const network = await ethers.provider.getNetwork();
    console.log("当前网络 chainId:", network.chainId);

    // if (await isLocalHostNet()) {
    //     // 本地网络，跳过此测试     
    //     console.log("⚠️  本地网络无法测试 Chainlink 预言机，跳过此设置");
    //     return;
    // }
    await AuctionFactory.setPriceFeed(
        tokenAddresses,
        priceFeedAddresses
    );
}

// 保存合约地址到缓存
function saveContractCache(contracts) {
    fs.writeFileSync(contractCachePath, JSON.stringify(contracts, null, 2));
    console.log("✅ 合约地址已缓存到:", contractCachePath);
}

// 从缓存加载合约地址
function loadContractCache() {
    if (fs.existsSync(contractCachePath)) {
        const cache = JSON.parse(fs.readFileSync(contractCachePath, "utf8"));
        console.log("📦 从缓存加载合约地址:", cache);
        return cache;
    }
    return null;
}

// 清除缓存（可选功能）
function clearContractCache() {
    if (fs.existsSync(contractCachePath)) {
        fs.unlinkSync(contractCachePath);
        console.log("🗑️  合约缓存已清除");
    }
}

async function isLocalHostNet() {
    const network = await ethers.provider.getNetwork();
    return network.chainId === 31337n;
}

function logBidPlacedEvent(receipt, eventName) {
    console.log(`=== 调试 ${eventName} ===`);
    console.log("交易回执日志数量:", receipt.logs.length);
    // 打印所有日志以便调试
    receipt.logs.forEach((log, index) => {
        try {
            const parsed = auctionContract.interface.parseLog(log);
            console.log(`日志 ${index}: 事件名称 = ${parsed.name}`);
            if (parsed.name === 'BidPlaced') {
                const { auctionId, tokenAddress, amount, higherBidder, highestPrice } = parsed.args;
                console.log(`=== ${eventName} ===`);
                console.log("拍卖ID:", auctionId.toString());
                console.log("代币地址:", tokenAddress === ethers.ZeroAddress ? "ETH" : tokenAddress);
                console.log("竞价金额:", tokenAddress === ethers.ZeroAddress ? ethers.formatEther(amount) : amount.toString());
                console.log("最高竞价人:", higherBidder);
                console.log("最高价格(USD):", (highestPrice / 1e18).toString());
                return parsed.args;
            }
        } catch (e) {
            console.log(`日志 ${index}: 无法解析 (可能来自其他合约)`);
        }
    });
    return null;
};

// describe("合约升级", async function () {
//     this.beforeEach(async function () {
//         //1.升级合约
//         // await deployments.fixture(["upgradeNftAuction"])
//         const v2 = await ethers.getContractFactory("NftAuctionV2")

//         nftProxyV2 = await upgrades.upgradeProxy(AuctionFactory.getAddress(), v2)

//         const auction = await AuctionFactory.auctions(0);
//         console.log("合约升级-成功升级:");
//     })


//     it("合约升级-数据一致性", async function () {
//         const auction = await AuctionFactory.auctions(0);
//         //3.读取合约的auction[0]
//         const auction2 = await AuctionFactory.auctions(0);
//         expect(auction2.startTime).to.equal(auction.startTime)
//         expect(auction2.tokenId).to.equal(auction.tokenId)
//     })

//     it("合约升级-新方法调用", async function () {
//         //验证新方法
//         expect(await nftProxyV2.HelloV2()).to.equal("Hello V2")
//     })

// })


