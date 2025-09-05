# NFT 拍卖平台文档

## 概述

NFT 拍卖平台是一个去中心化的拍卖系统，支持用户发布 NFT 拍卖、参与竞拍，并集成 Chainlink 价格预言机实现多币种竞拍。

## 核心功能

### 1. 发布拍卖
- 用户可以将自己的 NFT 发布到拍卖平台
- 设置拍卖持续时间和起拍价格
- 支持自定义拍卖参数

### 2. 竞拍出价
- 支持 ETH 和 ERC20 代币混合竞拍
- 集成 Chainlink 价格预言机进行实时价格转换
- 自动验证出价金额和处理资金转移

### 3. 结束拍卖
- 拍卖时间到期后自动结束
- NFT 自动转移给最高出价者
- 无人竞拍时 NFT 返还原主人
- 支持管理员提前结束拍卖

## 智能合约架构

### 合约文件
- `NftAuctionFactory.sol` - 拍卖工厂合约，负责创建和管理拍卖
- `NftAuction.sol` - 单个拍卖合约，处理具体的拍卖逻辑
- `NftAuctionV2.sol` - 升级版拍卖合约
- `INftAuctionErrors.sol` - 错误定义接口

### 关键特性
- **克隆模式**: 使用 OpenZeppelin Clones 降低部署成本
- **可升级性**: 支持合约升级和功能扩展
- **安全性**: 集成重入保护和权限控制
- **预言机集成**: 使用 Chainlink 获取实时价格数据

## 部署指南

### 部署脚本
- `00_deploy_nft.js` - 部署 NFT 合约
- `01_deploy_auction.js` - 部署拍卖合约
- `03_deploy_factory.js` - 部署拍卖工厂

### 部署命令
```bash
# 本地部署
npx hardhat deploy --network hardhat

# 测试网部署
npx hardhat deploy --network sepolia
```

## 测试指南

### 测试文件
- 测试文件路径: `test/index.js`
- 测试超时时间: 120秒

### 运行测试
```bash
# 本地测试
npx hardhat test --network hardhat

# 测试网测试
npx hardhat test --network sepolia
```

### 测试内容

#### 创建拍卖测试
- **拍卖 ID 唯一性验证**: 确保每个拍卖都有唯一的标识符
- **Chainlink 预言机集成测试**: 验证价格预言机在测试网上的正常工作（仅测试网）

#### 竞拍功能测试
- **ETH 和 USDC 混合竞拍**: 测试不同币种的竞拍功能
- **价格计算**: 验证基于 USD 的价格转换准确性
- **出价金额验证**: 确保出价金额符合最低要求
- **低价出价拒绝机制**: 测试低于当前最高价的出价被正确拒绝

#### 拍卖结束测试
- **提前结束拍卖的错误处理**: 验证未到期拍卖无法提前结束
- **NFT 转移给最高出价者**: 确保拍卖结束后 NFT 正确转移
- **无人竞拍时 NFT 返还原主人**: 测试无竞拍情况下的 NFT 处理
- **权限控制**: 验证仅 Owner 可结束拍卖的权限机制

### 测试特性
- **网络支持**: 支持本地网络和 Sepolia 测试网
- **合约缓存机制**: 提高测试效率，避免重复部署
- **预言机依赖**: 预言机相关测试必须在测试网络运行

### 注意事项
1. **网络要求**: 预言机功能测试需要在 Sepolia 测试网运行
2. **时间设置**: 拍卖持续时间以秒为单位
3. **资金准备**: 测试网测试需要准备足够的测试 ETH
4. **合约验证**: 部署后建议在 Etherscan 上验证合约

## API 参考

### NftAuctionFactory 主要方法
- `createAuction(duration, startPrice, nftContractAddress, tokenId)` - 创建拍卖
- `endAuction(auctionId)` - 结束拍卖
- `getAuctions()` - 获取所有拍卖地址
- `setPriceFeed(tokenAddresses, priceFeedAddresses)` - 设置价格预言机

### NftAuction 主要方法
- `placeBid(auctionID, tokenAddress, amount)` - 参与竞拍
- `getAuctionInfo()` - 获取拍卖信息
- `getRemainingTime()` - 获取剩余时间
- `isAuctionEnded()` - 检查拍卖是否结束

## 故障排除

### 常见问题
1. **拍卖未结束**: 检查区块时间是否正确推进
2. **预言机错误**: 确保在支持 Chainlink 的网络上测试
3. **权限错误**: 验证调用者是否有相应权限
4. **资金不足**: 确保账户有足够的 ETH 或代币余额

### 调试建议
- 使用 `console.log` 输出关键变量
- 检查事件日志获取详细信息
- 验证合约地址和参数正确性
- 确认网络配置和账户设置