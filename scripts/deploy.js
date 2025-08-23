const hre = require("hardhat");
import {HardhatUserConfig} from 'hardhat/types';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
let myERC721;

async function main() {
  // 获得将要部署的合约
  const MyERC721 = await hre.ethers.getContractFactory("MyERC721");
  myERC721 = await MyERC721.deploy("MyERC721", "M721", 10000, "0xD2ef731c60f75Cb9dfa06aa9f59B5e34bC87E8FA");

  console.log("MyERC721 deployed to:", myERC721.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });