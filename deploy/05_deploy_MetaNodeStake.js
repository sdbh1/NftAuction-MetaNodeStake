const { ethers, upgrades } = require("hardhat");
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("部署 MetaNodeToken 合约...");

  const MNT = await deploy("MyERC20", {
    from: deployer,
    args: ["MetaNodeToken", "MNT", 10000],
    log: true,
    waitConfirmations: 1,
  });

  console.log("部署 MetaNodeStake 合约...");
  //  部署获取到的MetaNode Token 地址
  const MetaNodeTokenAddress = MNT.address;
    console.log(`MetaNodeToken 合约部署到: ${MetaNodeTokenAddress}`);
    // 部署MetaNodeStake合约
  // 动态获取当前最新区块号
  const currentBlock = await ethers.provider.getBlockNumber();
  console.log(`当前最新区块号: ${currentBlock}`);
  // 质押起始区块高度,可以去sepolia上面读取最新的区块高度
  const startBlock = currentBlock;
  // 质押结束的区块高度,sepolia 出块时间是12s,想要质押合约运行x秒,那么endBlock = startBlock+x/12
  const endBlock = currentBlock + 10000000;
  // 每个区块奖励的MetaNode token的数量
  const MetaNodePerBlock = "20000000000000000";
  const Stake = await hre.ethers.getContractFactory("MetaNodeStake");
  console.log("Deploying MetaNodeStake...");
  const s = await upgrades.deployProxy(
    Stake,
    [MetaNodeTokenAddress, startBlock, endBlock, MetaNodePerBlock],
    { initializer: "initialize" }
  );
  //await box.deployed();
  console.log("MetaNodeStake deployed to:", await s.getAddress());
};

module.exports.tags = ["MetaNodeStakeDeploy"];
module.exports.dependencies = [];




