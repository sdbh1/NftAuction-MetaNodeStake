// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入 OpenZeppelin 的 ERC20 基础合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 导入 Ownable 用于权限控制（仅所有者可增发）
import "@openzeppelin/contracts/access/Ownable.sol";

// 继承 ERC20（标准功能）和 Ownable（所有者权限）
contract MyERC20 is ERC20, Ownable {
    // 构造函数：初始化代币名称、符号，并设置部署者为所有者
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        // 初始发行量：乘以 10^decimals（OpenZeppelin 的 ERC20 默认 decimals 为 18）
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    // 增发功能：仅所有者可调用
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Mint to zero address");
        // 调用 ERC20 内置的 _mint 函数（内部函数，负责更新余额和总供给）
        _mint(to, amount * 10 ** decimals());
    }

    // 可选：扩展其他自定义功能（如燃烧、税收机制等）
    function burn(uint256 amount) external {
        _burn(msg.sender, amount * 10 ** decimals());
    }
}