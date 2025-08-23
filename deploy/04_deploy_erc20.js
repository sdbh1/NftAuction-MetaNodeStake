
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("部署 MyERC20 合约...");
    
    const myERC20 = await deploy("MyERC20", {
        from: deployer,
        args: ["MyERC20", "M20", 10000],
        log: true,
        waitConfirmations: 1,
    });

    console.log(`MyERC20 合约部署到: ${myERC20.address}`);
};

module.exports.tags = ["MyERC20Deploy"];
module.exports.dependencies = [];