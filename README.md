
# Hardhat Demo 项目

## 项目概述

本项目是一个基于以太坊的 DeFi 平台，包含质押和 NFT 拍卖两大核心功能模块。

## 功能模块

### 1. 质押平台
- 质押 ETH/ERC20 代币获得 MetaNodeStake 代币
- 支持多池质押和奖励分配
- 详细文档：[质押平台文档](./docs/STAKING.md)

### 2. NFT 拍卖平台
- 发布 NFT 拍卖
- 支持 ETH 和 ERC20 代币竞拍
- 集成 Chainlink 价格预言机
- 详细文档：[拍卖平台文档](./docs/AUCTION.md)

## 快速开始

### 部署合约

**MetaNodeStake 和 MetaNodeToken**
```bash
npx hardhat deploy --network sepolia --tags MetaNodeStakeDeploy
```

### 运行测试

**拍卖平台测试**
```bash
# 本地测试 如果要测试预言机的部分，请替换为sepolia
npx hardhat test --network hardhat
```

**质押合约测试（Foundry）**
```bash
forge test
```

## 项目结构

```
├── contracts/          # 智能合约
│   ├── MetaNode/       # 质押相关合约
│   └── NftAuction/     # 拍卖相关合约
├── deploy/             # 部署脚本
├── test/               # 测试文件
├── docs/               # 详细文档
│   ├── STAKING.md      # 质押平台文档
│   └── AUCTION.md      # 拍卖平台文档
└── README.md           # 项目主文档
```

## 技术栈

- **智能合约**: Solidity ^0.8.30
- **开发框架**: Hardhat + Foundry
- **测试框架**: Mocha + Chai (Hardhat), Forge (Foundry)
- **升级模式**: OpenZeppelin Upgradeable Contracts
- **价格预言机**: Chainlink

## 许可证

MIT License