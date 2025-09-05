// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { Test, console } from "../../lib/forge-std/src/Test.sol";
import { MetaNodeStake } from "../../contracts/MetaNode/MetaNodeStake.sol";
import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";
import { MyERC20 } from "../../contracts/ERC20/MyERC20.sol";

contract MetaNodeStakeTest is Test {
	MetaNodeStake public metaNodeStake;
	MyERC20 public metaNodeToken;
	MyERC20 public stakingToken;
	MyERC20 public stakingToken2;

	// 定义多个用户地址
	address public admin;
	address public user1;
	address public user2;
	address public user3;

	// 测试常量
	uint256 constant INITIAL_SUPPLY = 1000000 * 10 ** 18;
	uint256 constant POOL_WEIGHT = 100;
	uint256 constant MIN_DEPOSIT_AMOUNT = 1 * 10 ** 18;
	uint256 constant UNSTAKE_LOCKED_BLOCKS = 100;
	uint256 constant META_NODE_PER_BLOCK = 10 * 10 ** 18;
	uint256 START_BLOCK = 1000;
	//质押合约,持续时间(秒)
	uint256 constant DURATION = 240000;
	bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

	function setUp() public {
		// 创建用户地址
		admin = makeAddr("admin");
		user1 = makeAddr("user1");
		user2 = makeAddr("user2");
		user3 = makeAddr("user3");

		// 给用户分配ETH
		vm.deal(admin, 100 ether);
		vm.deal(user1, 50 ether);
		vm.deal(user2, 50 ether);
		vm.deal(user3, 50 ether);

		// 以admin身份部署代币合约
		vm.startPrank(admin);
		metaNodeToken = new MyERC20("MetaNode", "MN", 10 * 10 ** 18);
		stakingToken = new MyERC20("StakingToken", "ST", 10 * 10 ** 18);
		stakingToken2 = new MyERC20("StakingToken2", "ST2", 10 * 10 ** 18);

		// 部署质押合约
		metaNodeStake = new MetaNodeStake();

		//获得当下链上最新区块高度
		START_BLOCK = block.number;
		// 初始化合约
		//12s一个区块，则结束区块为开始区块 + 持续时间/12个区块
		metaNodeStake.initialize(
			metaNodeToken,
			START_BLOCK,
			START_BLOCK + DURATION / 12,
			META_NODE_PER_BLOCK
		);
		// 给用户分配质押代币 (mint函数会自动处理decimals)
		stakingToken.mint(user1, 10000);
		stakingToken.mint(user2, 10000);
		stakingToken.mint(user3, 10000);

		// 给 MetaNodeStake 合约转移一些 MetaNode 代币用于奖励支付
		metaNodeToken.transfer(address(metaNodeStake), 100000 * 10 ** 18);
		vm.stopPrank();

		// 用户授权合约使用他们的代币
		vm.prank(user1);
		stakingToken.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user2);
		stakingToken.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user3);
		stakingToken.approve(address(metaNodeStake), type(uint256).max);

		_AddPool();
	}

	// ==================== 基础功能测试 ====================

	function testInitialize() public view {
		assertEq(metaNodeStake.startBlock(), START_BLOCK);
		assertEq(metaNodeStake.endBlock(), START_BLOCK + DURATION / 12);
		assertEq(metaNodeStake.MetaNodePerBlock(), META_NODE_PER_BLOCK);
		assertEq(address(metaNodeStake.MetaNode()), address(metaNodeToken));
		assertFalse(metaNodeStake.withdrawPaused());
		assertFalse(metaNodeStake.claimPaused());
	}

	function testCannotInitializeTwice() public {
		vm.prank(admin);
		vm.expectRevert();
		metaNodeStake.initialize(
			metaNodeToken,
			START_BLOCK,
			START_BLOCK + DURATION / 12,
			META_NODE_PER_BLOCK
		);
	}

	// ==================== 池管理测试 ====================

	function _AddPool() public {
		vm.prank(admin);
		vm.expectEmit(true, true, true, true);
		emit MetaNodeStake.AddPool(
			address(0),
			POOL_WEIGHT,
			block.number,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS
		);
		metaNodeStake.addPool(
			address(0),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);

		assertEq(metaNodeStake.poolLength(), 1);
		assertEq(metaNodeStake.totalPoolWeight(), POOL_WEIGHT);

		vm.prank(admin);
		vm.expectEmit(true, true, true, true);
		emit MetaNodeStake.AddPool(
			address(stakingToken),
			POOL_WEIGHT,
			block.number,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS
		);
		metaNodeStake.addPool(
			address(stakingToken),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		console.log("lastRewardBlock:", block.number);
		assertEq(metaNodeStake.poolLength(), 2);
		assertEq(metaNodeStake.totalPoolWeight(), POOL_WEIGHT * 2);
	}

	function testOnlyadminCanAddPool() public {
		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.addPool(
			address(stakingToken),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
	}

	function testSetPoolWeight() public {
		// 先添加池
		uint256 beforeTotalWeight = metaNodeStake.totalPoolWeight();
		uint256 pid = metaNodeStake.poolLength();
		vm.prank(admin);
		metaNodeStake.addPool(
			address(stakingToken2),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		uint256 newWeight = 200;
		vm.prank(admin);
		vm.expectEmit(true, false, false, true);
		emit MetaNodeStake.SetPoolWeight(pid, newWeight, beforeTotalWeight + newWeight);

		metaNodeStake.setPoolWeight(pid, newWeight, true);
		assertEq(metaNodeStake.totalPoolWeight(), beforeTotalWeight + newWeight);
	}

	function testCannotAddDuplicatePool() public {
		// 尝试添加已存在的质押代币地址（stakingToken 在 _AddPool 中已添加）
		vm.prank(admin);
		vm.expectRevert("stTokenAddress already added");
		metaNodeStake.addPool(
			address(stakingToken),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);

		// 尝试添加已存在的 ETH 池（address(0) 在 _AddPool 中已添加）
		vm.prank(admin);
		vm.expectRevert("invalid staking token address");
		metaNodeStake.addPool(
			address(0),
			POOL_WEIGHT * 2,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);

		// 验证池子数量没有增加
		assertEq(metaNodeStake.poolLength(), 2);
	}

	// ==================== 质押功能测试 ====================

	function testDepositERC20() public {
		// 添加ERC20池
		uint256 depositAmount = 5 * 10 ** 18;

		vm.prank(user1);
		vm.expectEmit(true, true, false, true);
		emit MetaNodeStake.Deposit(user1, 1, depositAmount);

		metaNodeStake.deposit(1, depositAmount);

		assertEq(metaNodeStake.stakingBalance(1, user1), depositAmount);
	}

	function testDepositETH() public {
		// 添加ETH池
		uint256 depositAmount = 2 ether;

		vm.prank(user1);
		vm.expectEmit(true, true, false, true);
		emit MetaNodeStake.Deposit(user1, 0, depositAmount);

		metaNodeStake.depositETH{ value: depositAmount }();

		assertEq(metaNodeStake.stakingBalance(0, user1), depositAmount);
	}

	function testDepositMinimumAmount() public {
		// 测试低于最小金额的存款
		vm.prank(user1);
		vm.expectRevert("deposit amount is too small");
		metaNodeStake.deposit(1, MIN_DEPOSIT_AMOUNT - 1);

		// 测试正好等于最小金额的存款
		vm.prank(user1);
		metaNodeStake.deposit(1, MIN_DEPOSIT_AMOUNT);
		assertEq(metaNodeStake.stakingBalance(1, user1), MIN_DEPOSIT_AMOUNT);
	}

	function testMultipleDeposits() public {
		uint256 firstDeposit = 3 * 10 ** 18;
		uint256 secondDeposit = 2 * 10 ** 18;

		vm.startPrank(user1);
		metaNodeStake.deposit(1, firstDeposit);
		metaNodeStake.deposit(1, secondDeposit);
		vm.stopPrank();

		assertEq(metaNodeStake.stakingBalance(1, user1), firstDeposit + secondDeposit);
	}

	// ==================== 解除质押功能测试 ====================

	function testUnstake() public {
		// 设置和存款
		uint256 depositAmount = 5 * 10 ** 18;
		uint256 unstakeAmount = 2 * 10 ** 18;

		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);

		vm.prank(user1);
		vm.expectEmit(true, true, false, true);
		emit MetaNodeStake.RequestUnstake(user1, 1, unstakeAmount);

		metaNodeStake.unstake(1, unstakeAmount);
		//让区块往后移动UNSTAKE_LOCKED_BLOCKS + 1个区块
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);
		(uint256 requestAmount, uint256 pendingWithdrawAmount) = metaNodeStake.withdrawAmount(
			1,
			user1
		);

		//打印下面的所有值
		assertEq(metaNodeStake.stakingBalance(1, user1), depositAmount - unstakeAmount);

		assertEq(requestAmount, unstakeAmount);
		assertEq(requestAmount, pendingWithdrawAmount);
	}

	function testUnstakeMoreThanBalance() public {
		uint256 depositAmount = 5 * 10 ** 18;

		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);

		vm.prank(user1);
		vm.expectRevert("Not enough staking token balance");
		metaNodeStake.unstake(1, depositAmount + 1);
	}

	function testWithdraw() public {
		// 设置和存款
		uint256 depositAmount = 5 * 10 ** 18;
		uint256 unstakeAmount = 2 * 10 ** 18;

		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);

		vm.prank(user1);
		metaNodeStake.unstake(1, unstakeAmount);

		// 推进区块到解锁时间
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);

		uint256 balanceBefore = stakingToken.balanceOf(user1);

		vm.prank(user1);
		vm.expectEmit(true, true, false, true);
		emit MetaNodeStake.Withdraw(user1, 1, unstakeAmount, block.number);

		metaNodeStake.withdraw(1);

		uint256 balanceAfter = stakingToken.balanceOf(user1);
		assertEq(balanceAfter - balanceBefore, unstakeAmount);

		(uint256 requestAmount, uint256 pendingWithdrawAmount) = metaNodeStake.withdrawAmount(
			0,
			user1
		);
		assertEq(requestAmount, 0);
		assertEq(pendingWithdrawAmount, 0);
	}

	function testWithdrawETH() public {
		// 添加ETH池
		uint256 depositAmount = 2 ether;
		uint256 unstakeAmount = 1 ether;

		vm.prank(user1);
		metaNodeStake.depositETH{ value: depositAmount }();

		vm.prank(user1);
		metaNodeStake.unstake(0, unstakeAmount);

		// 推进区块到解锁时间
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);

		uint256 balanceBefore = user1.balance;

		vm.prank(user1);
		metaNodeStake.withdraw(0);

		uint256 balanceAfter = user1.balance;
		assertEq(balanceAfter - balanceBefore, unstakeAmount);
	}

	function testWithdrawBeforeUnlock() public {
		uint256 depositAmount = 5 * 10 ** 18;
		uint256 unstakeAmount = 2 * 10 ** 18;

		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);

		vm.prank(user1);
		metaNodeStake.unstake(1, unstakeAmount);

		// 不推进区块，直接尝试提取
		vm.prank(user1);
		metaNodeStake.withdraw(1); // 应该不会提取任何金额
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);

		(uint256 requestAmount, uint256 pendingWithdrawAmount) = metaNodeStake.withdrawAmount(
			1,
			user1
		);
		assertEq(requestAmount, unstakeAmount);

		assertEq(pendingWithdrawAmount, unstakeAmount);
	}

	// ==================== 奖励领取测试 ====================

	function testClaim() public {
		// 推进到开始区块
		vm.roll(START_BLOCK);
		vm.prank(user1);
		metaNodeStake.depositETH{ value: 2 ether }();
		console.log("Before roll currentBlockNumuber:", block.number);
		// 推进一些区块以产生奖励
		vm.roll(START_BLOCK + 10);
		console.log("After roll currentBlockNumuber:", block.number);

		uint256 pendingReward = metaNodeStake.pendingMetaNode(0, user1);
		console.log("pendingReward:", pendingReward);
		assertGt(pendingReward, 0);

		uint256 balanceBefore = metaNodeToken.balanceOf(user1);
		console.log("balanceBefore:", balanceBefore);

		vm.expectEmit(true, true, false, true);
		emit MetaNodeStake.Claim(user1, 0, pendingReward);

		vm.prank(user1);
		metaNodeStake.claim(0);

		uint256 balanceAfter = metaNodeToken.balanceOf(user1);
		console.log("balanceAfter:", balanceAfter);
		console.log("balanceAfter - balanceBefore:", balanceAfter - balanceBefore);
		assertEq(balanceAfter - balanceBefore, pendingReward);
	}

	function testClaimMultipleUsers() public {
		vm.roll(START_BLOCK);

		// 两个用户同时存款
		vm.prank(user1);

		metaNodeStake.depositETH{ value: 2 ether }();

		vm.prank(user2);
		metaNodeStake.depositETH{ value: 2 ether }();

		// 推进区块
		vm.roll(START_BLOCK + 20);

		uint256 pending1 = metaNodeStake.pendingMetaNode(0, user1);
		uint256 pending2 = metaNodeStake.pendingMetaNode(0, user2);

		// 由于存款金额相同，奖励应该相近
		assertApproxEqRel(pending1, pending2, 0.01e18); // 1% tolerance

		vm.prank(user1);
		metaNodeStake.claim(0);

		vm.prank(user2);
		metaNodeStake.claim(0);

		assertGt(metaNodeToken.balanceOf(user1), 0);
		assertGt(metaNodeToken.balanceOf(user2), 0);
	}

	// ==================== 暂停功能测试 ====================

	function testPauseContract() public {
		vm.prank(admin);
		metaNodeStake.pauseWithdraw();

		assertTrue(metaNodeStake.withdrawPaused());

		vm.prank(admin);
		metaNodeStake.pauseClaim();

		assertTrue(metaNodeStake.claimPaused());

		vm.prank(user1);
		vm.expectRevert("withdraw is paused");
		metaNodeStake.withdraw(0); // 应该不会提取任何金额

		vm.prank(user1);
		vm.expectRevert("claim is paused");
		metaNodeStake.claim(0); // 应该不会领取任何奖励
	}

	function testPauseWithdraw() public {
		// 存款和解质押
		vm.prank(user1);
		metaNodeStake.deposit(1, 5 * 10 ** 18);

		vm.prank(user1);
		metaNodeStake.unstake(1, 2 * 10 ** 18);

		// 暂停提取
		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.PauseWithdraw();
		metaNodeStake.pauseWithdraw();

		assertTrue(metaNodeStake.withdrawPaused());

		// 推进区块
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);

		// 尝试提取应该失败
		vm.prank(user1);
		vm.expectRevert("withdraw is paused");
		metaNodeStake.withdraw(1);

		// 恢复提取
		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.UnpauseWithdraw();
		metaNodeStake.unpauseWithdraw();

		assertFalse(metaNodeStake.withdrawPaused());

		// 现在应该可以提取
		vm.prank(user1);
		metaNodeStake.withdraw(1);
	}

	function testPauseClaim() public {
		vm.roll(START_BLOCK);

		vm.prank(user1);
		metaNodeStake.deposit(1, 5 * 10 ** 18);

		vm.roll(START_BLOCK + 10);

		// 暂停领取
		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.PauseClaim();
		metaNodeStake.pauseClaim();

		assertTrue(metaNodeStake.claimPaused());

		// 尝试领取应该失败
		vm.prank(user1);
		vm.expectRevert("claim is paused");
		metaNodeStake.claim(1);

		// 恢复领取
		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.UnpauseClaim();
		metaNodeStake.unpauseClaim();

		assertFalse(metaNodeStake.claimPaused());

		// 现在应该可以领取
		vm.prank(user1);
		metaNodeStake.claim(1);
	}

	// ==================== 参数设置测试 ====================

	function testSetStartBlock() public {
		uint256 newStartBlock = 1500;

		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.SetStartBlock(newStartBlock);

		metaNodeStake.setStartBlock(newStartBlock);
		assertEq(metaNodeStake.startBlock(), newStartBlock);
	}

	function testSetEndBlock() public {
		uint256 newEndBlock = 3000;

		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.SetEndBlock(newEndBlock);

		metaNodeStake.setEndBlock(newEndBlock);
		assertEq(metaNodeStake.endBlock(), newEndBlock);
	}

	function testSetMetaNodePerBlock() public {
		uint256 newRate = 20 * 10 ** 18;

		vm.prank(admin);
		vm.expectEmit(false, false, false, true);
		emit MetaNodeStake.SetMetaNodePerBlock(newRate);

		metaNodeStake.setMetaNodePerBlock(newRate);
		assertEq(metaNodeStake.MetaNodePerBlock(), newRate);
	}

	// ==================== 权限测试 ====================

	function testOnlyAdminCanSetParameters() public {
		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.setStartBlock(1500);

		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.setEndBlock(3000);

		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.setMetaNodePerBlock(20 * 10 ** 18);

		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.pauseWithdraw();
	}

	function testOnlyadminCanManagePools() public {
		vm.prank(user1);
		MyERC20 temp20 = new MyERC20("StakingToken21", "ST21", 10 * 10 ** 18);

		vm.expectRevert();
		metaNodeStake.addPool(
			address(temp20),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);

		// 先添加池
		vm.prank(admin);
		metaNodeStake.addPool(
			address(temp20),
			POOL_WEIGHT,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);

		vm.prank(user1);
		vm.expectRevert();
		metaNodeStake.setPoolWeight(0, 200, true);
	}

	// ==================== 边界条件测试 ====================

	function testInvalidPoolId() public {
		vm.prank(user1);
		vm.expectRevert("invalid pid");
		metaNodeStake.deposit(99999, 1 * 10 ** 18);

		vm.prank(user1);
		vm.expectRevert("invalid pid");
		metaNodeStake.unstake(999991, 1 * 10 ** 18);

		vm.prank(user1);
		vm.expectRevert("invalid pid");
		metaNodeStake.withdraw(999991);

		vm.prank(user1);
		vm.expectRevert("invalid pid");
		metaNodeStake.claim(1111111);
	}

	function testZeroDeposit() public {
		vm.prank(user1);
		vm.expectRevert("deposit amount is too small");
		metaNodeStake.deposit(1, 0);
	}

	function testZeroUnstake() public {
		(
			address stTokenAddress,
			uint256 poolWeight,
			uint256 lastRewardBlock,
			uint256 accMetaNodePerST,
			uint256 stTokenAmount,
			uint256 minDepositAmount,
			uint256 unstakeLockedBlocks
		) = metaNodeStake.pool(1);
		stakingToken.balanceOf(user1);

		vm.prank(user1);
		metaNodeStake.deposit(1, 5 * 10 ** 18);

		vm.prank(user1);
		vm.expectRevert("Unstake amount must be greater than 0");
		metaNodeStake.unstake(1, 0);
	}

	// ==================== 复杂场景测试 ====================

	function testComplexStakingScenario() public {
		uint256 user1DepositPool1 = 5 * 10 ** 18;
		uint256 user1DepositPool2 = 10 * 10 ** 18;
		uint256 user2DepositPool1 = 3 * 10 ** 18;

		uint256 user1UnstakePool1 = 2 * 10 ** 18;

		// 添加两个池
		uint256 test1Pid = metaNodeStake.poolLength();
		uint256 test2Pid = metaNodeStake.poolLength() + 1;
		MyERC20 testToken1 = new MyERC20("test1", "ST1", 10 * 10 ** 18);
		MyERC20 testToken2 = new MyERC20("test2", "ST2", 10 * 10 ** 18);

		// 给用户分配质押代币 (mint函数会自动处理decimals)
		testToken1.mint(user1, 10000);
		testToken1.mint(user2, 10000);
		testToken2.mint(user1, 10000);
		testToken2.mint(user2, 10000);
		
		testToken1.mint(user1, 10000);
		testToken1.mint(user2, 10000);
		testToken2.mint(user1, 10000);
		testToken2.mint(user2, 10000);

		// 用户授权合约使用他们的代币
		vm.prank(user1);
		testToken1.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user1);
		testToken2.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user2);
		testToken1.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user2);
		testToken2.approve(address(metaNodeStake), type(uint256).max);

		vm.startPrank(admin);
		metaNodeStake.addPool(
			address(testToken1),
			200,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		metaNodeStake.addPool(
			address(testToken2),
			200,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		vm.stopPrank();

		vm.roll(START_BLOCK);

		// 用户1在两个池中都存款
		vm.prank(user1);
		metaNodeStake.deposit(test1Pid, user1DepositPool1);

		vm.prank(user1);
		metaNodeStake.deposit(test2Pid, user1DepositPool2);
		// 用户2只在第一个池存款
		vm.prank(user2);
		metaNodeStake.deposit(test1Pid, user2DepositPool1);

		// 推进区块
		vm.roll(START_BLOCK + 50);

		// 检查奖励分配
		uint256 user1Pool0Reward = metaNodeStake.pendingMetaNode(test1Pid, user1);
		uint256 user1Pool1Reward = metaNodeStake.pendingMetaNode(test2Pid, user1);
		uint256 user2Pool0Reward = metaNodeStake.pendingMetaNode(test1Pid, user2);
		uint256 user2Pool1Reward = metaNodeStake.pendingMetaNode(test2Pid, user2);

		assertGt(user1Pool0Reward, 0);
		assertGt(user1Pool1Reward, 0);
		assertGt(user2Pool0Reward, 0);
		assertEq(user2Pool1Reward, 0);

		// 用户1部分解质押
		vm.prank(user1);
		metaNodeStake.unstake(test1Pid, user1UnstakePool1);

		// 推进区块到解锁时间
		vm.roll(block.number + UNSTAKE_LOCKED_BLOCKS + 1);

		// 用户1提取解质押的代币
		vm.prank(user1);
		metaNodeStake.withdraw(test1Pid);

		// 所有用户领取奖励
		vm.prank(user1);
		metaNodeStake.claim(test1Pid);

		vm.prank(user1);
		metaNodeStake.claim(test2Pid);

		vm.prank(user2);
		metaNodeStake.claim(test1Pid);

		// 验证余额
		assertGt(metaNodeToken.balanceOf(user1), 0);
		assertGt(metaNodeToken.balanceOf(user2), 0);
		assertEq(metaNodeStake.stakingBalance(test1Pid, user1), user1DepositPool1 - user1UnstakePool1);
		assertEq(metaNodeStake.stakingBalance(test2Pid, user1), user1DepositPool2);
		assertEq(metaNodeStake.stakingBalance(test1Pid, user2), user2DepositPool1);
	}

	// ==================== 安全性测试 ====================

	function testReentrancyProtection() public {
		// 这个测试需要一个恶意合约来测试重入攻击
		// 由于合约使用了 ReentrancyGuard，应该能防止重入攻击
		vm.prank(user1);
		metaNodeStake.deposit(1, 5 * 10 ** 18);

		// 正常操作应该成功
		vm.prank(user1);
		metaNodeStake.unstake(1, 1 * 10 ** 18);
	}

	function testOverflowProtection() public {
		// 尝试存入极大的金额（应该被SafeMath保护）
		vm.prank(user1);
		// 这个测试取决于具体的溢出保护实现
		metaNodeStake.deposit(1, 1000 * 10 ** 18); // 正常金额应该成功
	}

	// ==================== 详细奖励计算测试 ====================

	/**
	 * @notice 测试单用户精确奖励计算
	 * 验证奖励计算公式：reward = (区块数 * 每区块奖励 * 池权重 / 总权重) * (用户质押量 / 池总质押量)
	 */
	function testRewardCalculationPrecision() public {
		// 设置测试参数
		uint256 depositAmount = 100 * 10 ** 18; // 100 tokens
		uint256 blockDuration = 10; // 10 blocks
		
		// 推进到开始区块
		vm.roll(START_BLOCK);
		
		// 用户1存款到池1
		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);
		
		// 推进指定区块数
		vm.roll(START_BLOCK + blockDuration);
		
		// 获取池信息
		(
			address stTokenAddress,
			uint256 poolWeight,
			uint256 lastRewardBlock,
			uint256 accMetaNodePerST,
			uint256 stTokenAmount,
			uint256 minDepositAmount,
			uint256 unstakeLockedBlocks
		) = metaNodeStake.pool(1);
		
		// 计算期望奖励
		// 公式：multiplier = blockDuration * META_NODE_PER_BLOCK
		// MetaNodeForPool = multiplier * poolWeight / totalPoolWeight
		// expectedReward = MetaNodeForPool (因为用户是唯一质押者)
		uint256 totalPoolWeight = metaNodeStake.totalPoolWeight();
		uint256 multiplier = blockDuration * META_NODE_PER_BLOCK;
		uint256 expectedReward = multiplier * poolWeight / totalPoolWeight;
		
		// 获取实际奖励
		uint256 actualReward = metaNodeStake.pendingMetaNode(1, user1);
		
		// 验证奖励计算精确性
		assertEq(actualReward, expectedReward, "Reward calculation should be precise");
		
		// 验证用户领取奖励后余额正确
		uint256 balanceBefore = metaNodeToken.balanceOf(user1);
		vm.prank(user1);
		metaNodeStake.claim(1);
		uint256 balanceAfter = metaNodeToken.balanceOf(user1);
		
		assertEq(balanceAfter - balanceBefore, expectedReward, "Claimed reward should match expected");
	}

	/**
	 * @notice 测试多用户奖励按比例分配
	 * 验证不同存款金额的用户按比例获得奖励
	 */
	function testMultiUserRewardDistribution() public {
		// 设置测试参数
		uint256 user1Deposit = 60 * 10 ** 18; // 60 tokens (60%)
		uint256 user2Deposit = 40 * 10 ** 18; // 40 tokens (40%)
		uint256 blockDuration = 20;
		
		// 推进到开始区块
		vm.roll(START_BLOCK);
		
		// 两个用户同时存款到池1
		vm.prank(user1);
		metaNodeStake.deposit(1, user1Deposit);
		
		vm.prank(user2);
		metaNodeStake.deposit(1, user2Deposit);
		
		// 推进区块
		vm.roll(START_BLOCK + blockDuration);
		
		// 获取奖励
		uint256 user1Reward = metaNodeStake.pendingMetaNode(1, user1);
		uint256 user2Reward = metaNodeStake.pendingMetaNode(1, user2);
		
		// 验证奖励比例 (user1:user2 = 60:40 = 3:2)
		// user1Reward / user2Reward 应该等于 user1Deposit / user2Deposit
		uint256 expectedRatio = (user1Deposit * 1e18) / user2Deposit; // 1.5 * 1e18
		uint256 actualRatio = (user1Reward * 1e18) / user2Reward;
		
		assertApproxEqRel(actualRatio, expectedRatio, 0.01e18, "Reward ratio should match deposit ratio");
		
		// 验证总奖励等于池应得的总奖励
		(
			,
			uint256 poolWeight,
			,,,,
		) = metaNodeStake.pool(1);
		
		uint256 totalPoolWeight = metaNodeStake.totalPoolWeight();
		uint256 multiplier = blockDuration * META_NODE_PER_BLOCK;
		uint256 expectedTotalReward = multiplier * poolWeight / totalPoolWeight;
		
		assertApproxEqRel(user1Reward + user2Reward, expectedTotalReward, 0.01e18, "Total rewards should match expected");
	}

	/**
	 * @notice 测试池权重对奖励分配的影响
	 * 验证不同权重的池如何影响奖励分配
	 */
	function testPoolWeightRewardImpact() public {
		// 创建两个不同权重的池
		MyERC20 testToken1 = new MyERC20("Test1", "T1", 10 * 10 ** 18);
		MyERC20 testToken2 = new MyERC20("Test2", "T2", 10 * 10 ** 18);
		
		// 给用户分配代币并授权
		testToken1.mint(user1, 10000);
		testToken2.mint(user2, 10000);
		
		vm.prank(user1);
		testToken1.approve(address(metaNodeStake), type(uint256).max);
		vm.prank(user2);
		testToken2.approve(address(metaNodeStake), type(uint256).max);
		
		// 添加两个池，权重比例为 3:1
		uint256 pool1Weight = 300;
		uint256 pool2Weight = 100;
		
		vm.startPrank(admin);
		metaNodeStake.addPool(
			address(testToken1),
			pool1Weight,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		
		uint256 pool1Id = metaNodeStake.poolLength() - 1;
		
		metaNodeStake.addPool(
			address(testToken2),
			pool2Weight,
			MIN_DEPOSIT_AMOUNT,
			UNSTAKE_LOCKED_BLOCKS,
			true
		);
		
		uint256 pool2Id = metaNodeStake.poolLength() - 1;
		vm.stopPrank();
		
		// 推进到开始区块
		vm.roll(START_BLOCK);
		
		// 两个用户存入相同金额到不同池
		uint256 depositAmount = 100 * 10 ** 18;
		
		vm.prank(user1);
		metaNodeStake.deposit(pool1Id, depositAmount);
		
		vm.prank(user2);
		metaNodeStake.deposit(pool2Id, depositAmount);
		
		// 推进区块
		uint256 blockDuration = 15;
		vm.roll(START_BLOCK + blockDuration);
		
		// 获取奖励
		uint256 user1Reward = metaNodeStake.pendingMetaNode(pool1Id, user1);
		uint256 user2Reward = metaNodeStake.pendingMetaNode(pool2Id, user2);
		
		// 验证奖励比例应该等于池权重比例 (3:1)
		uint256 expectedRatio = (pool1Weight * 1e18) / pool2Weight; // 3 * 1e18
		uint256 actualRatio = (user1Reward * 1e18) / user2Reward;
		
		assertApproxEqRel(actualRatio, expectedRatio, 0.01e18, "Reward ratio should match pool weight ratio");
	}

	/**
	 * @notice 测试奖励在不同时间段的累积
	 * 验证奖励在不同时间段的正确累积
	 */
	function testRewardAccumulationOverTime() public {
		uint256 depositAmount = 50 * 10 ** 18;
		
		// 推进到开始区块
		vm.roll(START_BLOCK);
		
		// 用户存款
		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);
		
		// 第一个时间段：5个区块
		vm.roll(START_BLOCK + 5);
		uint256 reward1 = metaNodeStake.pendingMetaNode(1, user1);
		
		// 第二个时间段：再推进5个区块
		vm.roll(START_BLOCK + 10);
		uint256 reward2 = metaNodeStake.pendingMetaNode(1, user1);
		
		// 第三个时间段：再推进10个区块
		vm.roll(START_BLOCK + 20);
		uint256 reward3 = metaNodeStake.pendingMetaNode(1, user1);
		
		// 验证奖励线性累积
		// reward2 应该是 reward1 的 2倍
		assertApproxEqRel(reward2, reward1 * 2, 0.01e18, "Reward should double after double time");
		
		// reward3 应该是 reward1 的 4倍
		assertApproxEqRel(reward3, reward1 * 4, 0.01e18, "Reward should quadruple after quadruple time");
		
		// 验证奖励增长的线性关系
		uint256 rewardDiff1 = reward2 - reward1; // 5个区块的奖励
		uint256 rewardDiff2 = reward3 - reward2; // 10个区块的奖励
		
		// rewardDiff2 应该是 rewardDiff1 的 2倍
		assertApproxEqRel(rewardDiff2, rewardDiff1 * 2, 0.01e18, "Reward growth should be linear");
	}

	/**
	 * @notice 测试边界条件下的奖励计算
	 * 验证开始/结束区块边界的奖励计算
	 */
	function testRewardCalculationEdgeCases() public {
		uint256 depositAmount = 100 * 10 ** 18;
		
		// 测试1：在开始区块之前存款
		// 确保不会出现区块号下溢
		uint256 beforeStartBlock = START_BLOCK > 10 ? START_BLOCK - 10 : 1;
		vm.roll(beforeStartBlock);
		vm.prank(user1);
		metaNodeStake.deposit(1, depositAmount);
		
		// 推进到开始区块
		vm.roll(START_BLOCK);
		uint256 rewardAtStart = metaNodeStake.pendingMetaNode(1, user1);
		assertEq(rewardAtStart, 0, "No reward should be generated before start block");
		
		// 推进到开始区块后
		vm.roll(START_BLOCK + 5);
		uint256 rewardAfterStart = metaNodeStake.pendingMetaNode(1, user1);
		assertGt(rewardAfterStart, 0, "Reward should be generated after start block");
		
		// 测试2：设置结束区块并验证
		uint256 endBlock = START_BLOCK + 100;
		vm.prank(admin);
		metaNodeStake.setEndBlock(endBlock);
		
		// 推进到结束区块
		vm.roll(endBlock);
		uint256 rewardAtEnd = metaNodeStake.pendingMetaNode(1, user1);
		
		// 推进到结束区块之后
		vm.roll(endBlock + 10);
		uint256 rewardAfterEnd = metaNodeStake.pendingMetaNode(1, user1);
		
		// 结束区块后奖励不应该继续增长
		assertEq(rewardAtEnd, rewardAfterEnd, "Reward should not increase after end block");
		
		// 测试3：验证单个区块的奖励计算（重新开始一个新的测试场景）
		// 重置到开始区块附近进行单独测试
		vm.roll(START_BLOCK + 50);
		vm.prank(user2);
		metaNodeStake.deposit(1, depositAmount);
		
		vm.roll(START_BLOCK + 51);
		uint256 singleBlockReward = metaNodeStake.pendingMetaNode(1, user2);
		
		// 计算期望的单区块奖励
		(
			,
			uint256 poolWeight,
			,,,,
		) = metaNodeStake.pool(1);
		
		uint256 totalPoolWeight = metaNodeStake.totalPoolWeight();
		uint256 totalStaked = metaNodeStake.stakingBalance(1, user1) + metaNodeStake.stakingBalance(1, user2);
		
		// 避免除零错误
		if (totalStaked > 0) {
			uint256 expectedSingleBlockReward = (META_NODE_PER_BLOCK * poolWeight / totalPoolWeight) * depositAmount / totalStaked;
			assertApproxEqRel(singleBlockReward, expectedSingleBlockReward, 0.01e18, "Single block reward should be calculated correctly");
		}
	}
}
