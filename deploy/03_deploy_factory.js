module.exports.tags = ["nft"];
const { deployments, upgrades, ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// deploy/01_deploy_nft.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("====03_deploy_factory start====");
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址:", deployer);
    const nftAuctionFactory = await ethers.getContractFactory("NftAuctionFactory")
    const nftAuctionFactoryProxy = await upgrades.deployProxy(nftAuctionFactory, [deployer], {
        initializer: "initialize"
    }
    );
    await nftAuctionFactoryProxy.waitForDeployment();
    const nftAuctionFactoryAddress = await nftAuctionFactoryProxy.getAddress()
    console.log("代理工厂合约地址:", nftAuctionFactoryAddress)
    const factoryImplementationAddress = await upgrades.erc1967.getImplementationAddress(nftAuctionFactoryProxy.target)
    console.log("实现工厂合约地址:", factoryImplementationAddress)

    const storagePath = path.resolve(__dirname, "./.cache/proxyNftAuctionFactory.json");
    fs.writeFileSync(
        storagePath,
        JSON.stringify({
            nftAuctionFactoryAddress,
            factoryImplementationAddress,
            abi: nftAuctionFactory.interface.format("json"),
        })
    );
    await save("NftAuctionFactoryProxy", {
        abi: nftAuctionFactory.interface.format("json"),
        address: nftAuctionFactoryProxy.target,
        args: [],
        log: true,
    })

    console.log("====03_deploy_factory end====");
};
module.exports.tags = ['deployNftAuctionFactory'];