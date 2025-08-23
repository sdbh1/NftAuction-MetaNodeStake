module.exports.tags = ["nft"];
const { deployments, upgrades, ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// deploy/01_deploy_nft.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    // console.log("====01_deploy_auction start====");
    // const { save } = deployments;
    // const { deployer } = await getNamedAccounts();
    // console.log("部署用户地址:", deployer);
    // const NftAuction = await ethers.getContractFactory("NftAuction")

    // const nftAuctionProxy = await upgrades.deployProxy(NftAuction, [deployer], {
    //     initializer: "initialize"
    // }
    // );

    // await nftAuctionProxy.waitForDeployment();
    // const proxyAddress = await nftAuctionProxy.getAddress()
    // console.log("代理合约地址:", proxyAddress)
    // const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress)
    // console.log("实现合约地址:", implementationAddress)

    // const storagePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
    // fs.writeFileSync(
    //     storagePath,
    //     JSON.stringify({
    //         proxyAddress,
    //         implementationAddress,
    //         abi: NftAuction.interface.format("json"),
    //     })
    // );
    // await save("NftAuctionProxy", {
    //     abi: NftAuction.interface.format("json"),
    //     address: proxyAddress,
    //     args: [],
    //     log: true,
    // })

    // console.log("====01_deploy_auction end====\n");
};
module.exports.tags = ['deployNftAuction'];