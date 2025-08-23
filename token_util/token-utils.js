const fs = require('fs');
const path = require('path');

/**
 * 代币配置工具类
 * 用于读取和查询代币合约地址和价格预言机地址
 */
class TokenUtils {
  constructor() {
    this.config = null;
    this.loadConfig();
  }

  /**
   * 加载配置文件
   */
  loadConfig() {
    try {
      const configPath = path.join(__dirname, 'token-config.json');
      const configData = fs.readFileSync(configPath, 'utf8');
      this.config = JSON.parse(configData);
    } catch (error) {
      throw new Error(`加载配置文件失败: ${error.message}`);
    }
  }

  /**
   * 根据链ID获取网络名称
   * @param {number} chainId - 链ID
   * @returns {string|null} 网络名称
   */
  getNetworkByChainId(chainId) {
    for (const [networkName, networkConfig] of Object.entries(this.config.networks)) {
      if (networkConfig.chainId === chainId) {
        return networkName;
      }
    }
    return null;
  }

  /**
   * 获取代币信息
   * @param {number|string} chainIdOrNetwork - 链ID或网络名称
   * @param {string} tokenSymbol - 代币符号（如 'ETH', 'BTC', 'USDC'）
   * @returns {object|null} 代币信息对象
   */
  getTokenInfo(chainIdOrNetwork, tokenSymbol) {
    let networkName;
    
    // 如果传入的是数字，则认为是链ID
    if (typeof chainIdOrNetwork === 'number') {
      networkName = this.getNetworkByChainId(chainIdOrNetwork);
    } else {
      networkName = chainIdOrNetwork;
    }

    if (!networkName || !this.config.networks[networkName]) {
      return null;
    }

    const network = this.config.networks[networkName];
    const token = network.tokens[tokenSymbol.toUpperCase()];
    
    if (!token) {
      return null;
    }

    return {
      name: token.name,
      symbol: token.symbol,
      decimals: token.decimals,
      contractAddress: token.contractAddress,
      priceFeedAddress: token.priceFeedAddress,
      description: token.description,
      network: {
        name: network.name,
        chainId: network.chainId
      }
    };
  }

  /**
   * 获取代币合约地址
   * @param {number|string} chainIdOrNetwork - 链ID或网络名称
   * @param {string} tokenSymbol - 代币符号
   * @returns {string|null} 合约地址
   */
  getContractAddress(chainIdOrNetwork, tokenSymbol) {
    const tokenInfo = this.getTokenInfo(chainIdOrNetwork, tokenSymbol);
    return tokenInfo ? tokenInfo.contractAddress : null;
  }

  /**
   * 获取价格预言机地址
   * @param {number|string} chainIdOrNetwork - 链ID或网络名称
   * @param {string} tokenSymbol - 代币符号
   * @returns {string|null} 预言机地址
   */
  getPriceFeedAddress(chainIdOrNetwork, tokenSymbol) {
    const tokenInfo = this.getTokenInfo(chainIdOrNetwork, tokenSymbol);
    return tokenInfo ? tokenInfo.priceFeedAddress : null;
  }

  /**
   * 获取指定网络的所有代币列表
   * @param {number|string} chainIdOrNetwork - 链ID或网络名称
   * @returns {array} 代币符号数组
   */
  getAvailableTokens(chainIdOrNetwork) {
    let networkName;
    
    if (typeof chainIdOrNetwork === 'number') {
      networkName = this.getNetworkByChainId(chainIdOrNetwork);
    } else {
      networkName = chainIdOrNetwork;
    }

    if (!networkName || !this.config.networks[networkName]) {
      return [];
    }

    return Object.keys(this.config.networks[networkName].tokens);
  }

  /**
   * 获取所有支持的网络
   * @returns {array} 网络信息数组
   */
  getSupportedNetworks() {
    return Object.entries(this.config.networks).map(([name, config]) => ({
      name,
      displayName: config.name,
      chainId: config.chainId
    }));
  }

  /**
   * 获取配置元数据
   * @returns {object} 元数据信息
   */
  getMetadata() {
    return this.config.metadata;
  }
}

// 创建单例实例
const tokenUtils = new TokenUtils();

// 导出便捷函数
module.exports = {
  TokenUtils,
  
  // 便捷函数
  getTokenInfo: (chainIdOrNetwork, tokenSymbol) => 
    tokenUtils.getTokenInfo(chainIdOrNetwork, tokenSymbol),
  
  getContractAddress: (chainIdOrNetwork, tokenSymbol) => 
    tokenUtils.getContractAddress(chainIdOrNetwork, tokenSymbol),
  
  getPriceFeedAddress: (chainIdOrNetwork, tokenSymbol) => 
    tokenUtils.getPriceFeedAddress(chainIdOrNetwork, tokenSymbol),
  
  getAvailableTokens: (chainIdOrNetwork) => 
    tokenUtils.getAvailableTokens(chainIdOrNetwork),
  
  getSupportedNetworks: () => 
    tokenUtils.getSupportedNetworks(),
  
  getMetadata: () => 
    tokenUtils.getMetadata()
};

// 使用示例（注释掉，仅供参考）
/*
// 使用链ID查询
console.log('ETH on Mainnet:', getTokenInfo(1, 'ETH'));
console.log('USDC Contract on Sepolia:', getContractAddress(11155111, 'USDC'));
console.log('BTC Price Feed on Mainnet:', getPriceFeedAddress('mainnet', 'BTC'));

// 查询可用代币
console.log('Mainnet tokens:', getAvailableTokens(1));
console.log('Supported networks:', getSupportedNetworks());
*/