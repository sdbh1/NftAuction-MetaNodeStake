module.exports.tags = ["nft"];
const { deployments, upgrades, ethers } = require("hardhat");

// deploy/01_deploy_nft.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log("====00_deploy_nft start====");
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址:", deployer);

    await deploy('MyERC721', {
        from: deployer,
        args: ["MyERC721", "M721", 10000],
        log: true,
    });
    console.log("====00_deploy_nft end====\n");
};
module.exports.tags = ['MyERC721Deploy'];