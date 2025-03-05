// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/StakeV2.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWETH} from "./mocks/MockWBERA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./mocks/SimpleZapperMock.sol";

contract KodiakVaultV1 {
    IERC20 public token0;
    IERC20 public token1;

    constructor(IERC20 _token0, IERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}

abstract contract StakeV2_BaseTest {
    StakeV2 public stakeV2;
    MockERC20 public token;
    MockWETH public wbera;
    SimpleZapperMock public mockZapper;

    function setUp() public virtual {
        token = new MockERC20("MockERC20", "MockERC20", 18);
        wbera = new MockWETH();
        address owner = address(this);
        address manager = address(this);
        mockZapper = new SimpleZapperMock(token, wbera);
        stakeV2 = new StakeV2(token, mockZapper, owner, manager, IWETH(wbera));
    }

    function test() public {}
}

contract StakeV2_HandleExcessDebt is Test {
    MockERC20 public token;
    MockWETH public wbera;

    function setUp() public virtual {
        token = new MockERC20("MockERC20", "MockERC20", 18);
        wbera = new MockWETH();
    }

    // make sure we can handle excess yeet when its token0
    function test_handleExcessYeetToken0() public {
        address owner = address(this);
        address manager = address(this);
        KodiakVaultV1 kodiakVault = new KodiakVaultV1(token, wbera);
        SimpleZapperMock mockZapper = new SimpleZapperMock(kodiakVault.token0(), kodiakVault.token1());
        StakeV2 stakeV2 = new StakeV2(token, mockZapper, owner, manager, IWETH(wbera));

        token.mint(address(this), 100 ether);
        token.approve(address(stakeV2), 50 ether);
        stakeV2.stake(50 ether);

        // simulate debt by adding excess token0
        token.transfer(address(stakeV2), 50 ether);
        //zapper
        mockZapper.setReturnValues(1, 1); // does not matter

        stakeV2.depositReward{
                value: 1 ether
            }();

        assertEq(100 ether, token.balanceOf(address(stakeV2)));

        stakeV2.executeRewardDistributionYeet(
            IZapper.SingleTokenSwap(50 ether, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(kodiakVault), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        assertEq(50 ether, token.balanceOf(address(stakeV2)));
        assertEq(50 ether, token.balanceOf(address(mockZapper)));
    }

    // make sure we can handle excess yeet when its token1
    function test_handleExcessYeetToken1() public {
        address owner = address(this);
        address manager = address(this);

        KodiakVaultV1 kodiakVault = new KodiakVaultV1(token, wbera);
        SimpleZapperMock mockZapper = new SimpleZapperMock(kodiakVault.token0(), kodiakVault.token1());
        StakeV2 stakeV2 = new StakeV2(token, mockZapper, owner, manager, IWETH(wbera));

        token.mint(address(this), 100 ether);
        token.approve(address(stakeV2), 50 ether);
        stakeV2.stake(50 ether);

        // simulate debt by adding excess token0
        token.transfer(address(stakeV2), 50 ether);
        //zapper
        mockZapper.setReturnValues(1, 1); // does not matter

        stakeV2.depositReward{
                value: 1 ether
            }();

        assertEq(100 ether, token.balanceOf(address(stakeV2)));

        stakeV2.executeRewardDistributionYeet(
            IZapper.SingleTokenSwap(50 ether, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(kodiakVault), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        assertEq(50 ether, token.balanceOf(address(stakeV2)));
        assertEq(50 ether, token.balanceOf(address(mockZapper)));
    }
}

contract StakeV2_Manager is Test {
    Manager private _managerContract;

    function setUp() public {
        _managerContract = new Manager(address(0x00a), address(0x00a));
    }

    function test_addManager() public {
        vm.startPrank(address(0x00a));
        _managerContract.addManager(address(0x00b));
        assertTrue(_managerContract.managers(address(0x00b)));
    }

    function test_removeManager() public {
        vm.startPrank(address(0x00a));
        assertFalse(_managerContract.managers(address(0x00c)));
        _managerContract.addManager(address(0x00c));
        assertTrue(_managerContract.managers(address(0x00c)));
        _managerContract.removeManager(address(0x00c));
        assertFalse(_managerContract.managers(address(0x00c)));
    }

    function test_onlyOwner() public {
        vm.startPrank(address(0x00b));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x00b)));
        _managerContract.addManager(address(0x00b));
    }
}

contract StakeV2_Ctor is Test, StakeV2_BaseTest {
    function test_setsTheManager() public {
        assertEq(stakeV2.managers(address(this)), true);
        assertEq(stakeV2.managers(address(0x00a)), false);
    }

    function test_setsTheStakingToken() public {
        assertEq(address(stakeV2.stakingToken()), address(token));
    }
}

contract StakeV2_DepositRewards is Test, StakeV2_BaseTest {
    function test_depositRewards() public {
        uint256 rewardAmount = 1000 ether;

        stakeV2.depositReward{value: rewardAmount}();

        assertEq(address(stakeV2).balance, rewardAmount, "Rewards were not deposited correctly");
        assertEq(stakeV2.accumulatedRewards(), rewardAmount, "Total rewards were not updated correctly");
    }

    function test_depositRewardsEmit() public {
        uint256 rewardAmount = 1000 ether;

        vm.expectEmit();
        emit StakeV2.RewardDeposited(address(this), rewardAmount);

        stakeV2.depositReward{value: rewardAmount}();
    }
}

interface IVault {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(uint256, address, address) external returns (uint256);
}

contract StakeV2_ExecuteRewardsDistrubution is Test, StakeV2_BaseTest {
    function test_executeRewardDistribution_noRewards() public {
        vm.expectRevert("No rewards to distribute");
        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );
    }

    function test_executeRewardDistribution_withRewards() public {
        // Setup
        token.mint(address(this), 1000 ether);
        token.approve(address(stakeV2), 10 ether);
        stakeV2.stake(10 ether);
        uint256 rewardAmount = 1 ether;
        uint256 expectedIslandTokens = 0 ether;
        uint256 expectedShares = 50 ether;
        mockZapper.setReturnValues(expectedIslandTokens, expectedShares);

        // Deposit rewards
        vm.deal(address(this), rewardAmount);
        stakeV2.depositReward{value: rewardAmount}();

        uint256 expectedRewardIndex = expectedShares * 1 ether / stakeV2.totalSupply();
        // Execute reward distribution
        vm.expectEmit(true, true, false, true);
        emit StakeV2.RewardsDistributed(rewardAmount, expectedRewardIndex);

        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        // Assertions
        assertEq(stakeV2.accumulatedRewards(), 0, "Accumulated rewards should be reset to 0");
        assertEq(stakeV2.rewardIndex(), expectedRewardIndex, "Reward index should be updated correctly");
    }

    function test_executeRewardDistribution_zeroTotalSupply() public {
        // Setup
        uint256 rewardAmount = 1 ether;
        uint256 expectedIslandTokens = 0 ether;
        uint256 expectedShares = 50 ether;
        mockZapper.setReturnValues(expectedIslandTokens, expectedShares);

        // Deposit rewards
        vm.deal(address(this), rewardAmount);
        stakeV2.depositReward{value: rewardAmount}();

        // Execute reward distribution
        vm.expectEmit(true, true, false, true);
        emit StakeV2.RewardsDistributed(rewardAmount, 0);

        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        // Assertions
        assertEq(stakeV2.accumulatedRewards(), 0, "Accumulated rewards should be reset to 0");
        assertEq(stakeV2.rewardIndex(), 0, "Reward index should remain 0 when totalSupply is 0");
    }

    function test_executeRewardDistribution_onlyManager() public {
        vm.prank(address(0xdead));
        vm.expectRevert("Only manager can call this function");
        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );
    }

    function test_accumulatedRewardsToken0() public {
        token.mint(address(this), 100 ether);
        token.approve(address(stakeV2), 50 ether);
        stakeV2.stake(50 ether);
        token.transfer(address(stakeV2), 50 ether);

        assertEq(50 ether, stakeV2.accumulatedDeptRewardsYeet());
    }

    function test_handleExcessToken1DepositWBERA() public {
        address add = makeAddr("Koala");
        stakeV2.addManager(add);
        vm.deal(add, 1000 ether);
        vm.startPrank(add);
        // Add excess wbera to staking contract to simulate debt
        wbera.deposit{
                value: 100 ether
            }();
        wbera.transfer(address(stakeV2), 100 ether);

        vm.expectEmit(address(stakeV2));
        emit StakeV2.RewardDeposited(address(stakeV2), 100 ether);
        stakeV2.depositWBERA(100 ether);

        assertEq(0, wbera.balanceOf(address(stakeV2)));
    }
}

contract StakeV2_ClaimNativeRewards is Test, StakeV2_BaseTest {
    function test_claimNativeRewards_noRewards() public {
        vm.expectRevert("No rewards to claim");
        stakeV2.claimRewardsInNative(
            100,
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultUnstakingParams(address(0), 0, 0, address(0)),
            IZapper.VaultRedeemParams(address(0), address(0), 0, 0)
        );
    }

    function test_claimNativeRewards_withRewards() public {
        // Setup
        token.mint(address(this), 1000 ether);
        token.approve(address(stakeV2), 10 ether);
        stakeV2.stake(10 ether);
        uint256 rewardAmount = 1 ether;
        uint256 expectedIslandTokens = 0 ether;
        uint256 expectedShares = 50 ether;
        mockZapper.setReturnValues(expectedIslandTokens, expectedShares);

        // Deposit rewards
        vm.deal(address(this), rewardAmount);
        stakeV2.depositReward{value: rewardAmount}();

        // Claim rewards
        vm.expectEmit();
        emit StakeV2.RewardsDistributed(rewardAmount, 5 ether);

        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        stakeV2.claimRewardsInNative(
            stakeV2.calculateRewardsEarned(address(this)),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultUnstakingParams(address(0), 0, 0, address(0)),
            IZapper.VaultRedeemParams(address(token), address(0), 0, 0)
        );

        // Assertions
        assertEq(stakeV2.accumulatedRewards(), 0, "Accumulated rewards should be reset to 0");
        assertEq(stakeV2.rewardIndex(), 5 ether, "Reward index should be updated correctly");
        assertEq(stakeV2.calculateRewardsEarned(address(this)), 0, "Rewards earned should be updated correctly");
    }
}

contract StakeV2_Reward is Test, StakeV2_BaseTest {
    function test_rewardIndex() public {
        assertEq(stakeV2.rewardIndex(), 0, "Reward index should be initialized to 0");
        address staker1 = makeAddr("staker_one");
        address staker2 = makeAddr("staker_two");
        uint256 initialRewards = stakeV2.calculateRewardsEarned(staker1);
        assertEq(initialRewards, 0, "initial rewards should be 0");

        vm.startPrank(staker1);
        token.mint(address(staker1), 1000 ether);
        token.approve(address(stakeV2), 10 ether);
        stakeV2.stake(10 ether);
        vm.stopPrank();

        vm.startPrank(staker2);
        token.mint(address(staker2), 1000 ether);
        token.approve(address(stakeV2), 10 ether);
        stakeV2.stake(10 ether);
        vm.stopPrank();

        uint256 expectedIslandTokens = 0 ether;
        uint256 rewardAmount = 1 ether;

        mockZapper.setReturnValues(expectedIslandTokens, rewardAmount); //simulates the zapper logic at a 1 : 1 ratio for vaultsSharesMinted :accumulatedRewards
        stakeV2.depositReward{value: rewardAmount}();
        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        uint256 staker1Rewards = stakeV2.calculateRewardsEarned(staker1);
        uint256 staker2Rewards = stakeV2.calculateRewardsEarned(staker2);

        assertEq(staker1Rewards, 0.5 ether, "staker1 rewards should be 0.5 ether");
        assertEq(staker2Rewards, 0.5 ether, "staker2 rewards should be 0.5 ether");

        vm.startPrank(staker1);
        stakeV2.claimRewardsInNative(
            stakeV2.calculateRewardsEarned(staker1),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultUnstakingParams(address(0), 0, 0, address(0)),
            IZapper.VaultRedeemParams(address(token), address(0), 0, 0)
        );
        vm.stopPrank();

        assertEq(stakeV2.calculateRewardsEarned(staker1), 0, "staker1 rewards should be 0");
        assertEq(stakeV2.calculateRewardsEarned(staker2), 0.5 ether, "staker2 rewards should be 0.5 ether");

        stakeV2.depositReward{value: rewardAmount}();
        stakeV2.executeRewardDistribution(
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.SingleTokenSwap(0, 0, 0, address(0), ""),
            IZapper.KodiakVaultStakingParams(address(0), 0, 0, 0, 0, 0, address(0)),
            IZapper.VaultDepositParams(address(0), address(0), 0)
        );

        assertEq(stakeV2.calculateRewardsEarned(staker1), 0.5 ether, "staker1 rewards should be 0.5 ether");
        assertEq(stakeV2.calculateRewardsEarned(staker2), 1 ether, "staker2 rewards should be 1 ether");
    }
}
