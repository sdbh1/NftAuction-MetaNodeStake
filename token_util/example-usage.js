/**
 * token-utils.js 使用示例
 * 演示如何使用代币配置工具类查询代币信息
 */

const {
  getTokenInfo,
  getContractAddress,
  getPriceFeedAddress,
  getAvailableTokens,
  getSupportedNetworks,
  getMetadata
} = require('./token-utils');

console.log('=== 代币配置工具使用示例 ===\n');

// 1. 查询支持的网络
console.log('1. 支持的网络:');
const networks = getSupportedNetworks();
networks.forEach(network => {
  console.log(`   - ${network.displayName} (${network.name}): Chain ID ${network.chainId}`);
});
console.log();

// 2. 使用链ID查询代币信息
console.log('2. 使用链ID查询代币信息:');
const ethMainnet = getTokenInfo(1, 'ETH');
console.log('   ETH on Mainnet (Chain ID 1):', ethMainnet);

const usdcSepolia = getTokenInfo(11155111, 'USDC');
console.log('   USDC on Sepolia (Chain ID 11155111):', usdcSepolia);
console.log();

// 3. 使用网络名称查询代币信息
console.log('3. 使用网络名称查询代币信息:');
const btcMainnet = getTokenInfo('mainnet', 'BTC');
console.log('   BTC on mainnet:', btcMainnet);

const linkSepolia = getTokenInfo('sepolia', 'LINK');
console.log('   LINK on sepolia:', linkSepolia);
console.log();

// 4. 只获取合约地址
console.log('4. 获取合约地址:');
console.log('   USDC合约地址 (Mainnet):', getContractAddress(1, 'USDC'));
console.log('   LINK合约地址 (Sepolia):', getContractAddress('sepolia', 'LINK'));
console.log();

// 5. 只获取价格预言机地址
console.log('5. 获取价格预言机地址:');
console.log('   ETH价格预言机 (Mainnet):', getPriceFeedAddress('mainnet', 'ETH'));
console.log('   BTC价格预言机 (Sepolia):', getPriceFeedAddress(11155111, 'BTC'));
console.log();

// 6. 查询网络支持的所有代币
console.log('6. 查询网络支持的代币:');
console.log('   Mainnet支持的代币:', getAvailableTokens('mainnet'));
console.log('   Sepolia支持的代币:', getAvailableTokens(11155111));
console.log();

// 7. 获取配置元数据
console.log('7. 配置元数据:');
const metadata = getMetadata();
console.log('   版本:', metadata.version);
console.log('   描述:', metadata.description);
console.log('   最后更新:', metadata.lastUpdated);
console.log('   数据源:', metadata.sources);
console.log('   注意事项:', metadata.notes);
console.log();

// 8. 错误处理示例
console.log('8. 错误处理示例:');
const invalidToken = getTokenInfo(1, 'INVALID_TOKEN');
console.log('   查询不存在的代币:', invalidToken); // 应该返回 null

const invalidNetwork = getTokenInfo(999999, 'ETH');
console.log('   查询不存在的网络:', invalidNetwork); // 应该返回 null

console.log('\n=== 示例结束 ===');