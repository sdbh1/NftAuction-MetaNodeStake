module.exports.tags = ["nft"];
const { deployments, upgrades, ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("====02_upgrade_nft start=====");

    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址:", deployer);

    const storePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
    if (!fs.existsSync(storePath)) {
        console.error("缓存文件不存在:", storePath);
        return;
    }

    const storeData = fs.readFileSync(storePath, "utf-8");
    const { proxyAddress, implAddress, abi } = JSON.parse(storeData);

    const NftAuctioV2 = await ethers.getContractFactory("NftAuctionV2")
 
    const nftProxyV2 = await upgrades.upgradeProxy(proxyAddress, NftAuctioV2)
    await nftProxyV2.waitForDeployment()

    const proxyAddressV2 = await nftProxyV2.getAddress()
    console.log("V2代理合约地址:", proxyAddressV2)
    const implAddressV2 = await upgrades.erc1967.getImplementationAddress(proxyAddressV2)
    console.log("V2实现合约地址:", implAddressV2)

    console.log("====02_upgrade_nft end====\n");
};
module.exports.tags = ['upgradeNftAuction'];