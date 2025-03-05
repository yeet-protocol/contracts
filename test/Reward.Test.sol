pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/YeetGameSettings.sol";
import {Reward} from "../src/Reward.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {RewardSettings} from "../src/RewardSettings.sol";

contract Reward_OneYeet is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));

        reward.addYeetVolume(address(0xaa), 1000);
    }

    function test_AddVolumeToTotalYeetVolume() public {
        assertEq(reward.totalYeetVolume(1), 1000);
    }

    function test_AddVolumeToUserYeetVolume() public {
        assertEq(reward.userYeetVolume(1, address(0xaa)), 1000);
    }

    function test_userHasZeroClaimsBeforeEndOfEpoch() public {
        assertEq(reward.getClaimableAmount(address(0xaa)), 0);
    }

    function test_callingClaimWithNotingToClaimReverts() public {
        vm.expectRevert("Nothing to claim");
        reward.claim();
    }
}

// When a user yeets, there should be rewards in the next epoch
contract Reward_OneYeetAndClaimNextEpoch is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));

        reward.addYeetVolume(address(0xaa), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
    }

    function test_userHasClaimsAfterEndOfEpoch() public {
        uint256 expected = uint256(1_312_810 * 1 ether) / 7;
        assertEq(reward.getClaimableAmount(address(0xaa)), expected);
    }

    function test_claimReturnsAmountEarned() public {
        vm.startPrank(address(0xaa));
        assertEq(reward.token().balanceOf(address(0xaa)), 0);
        reward.claim();
        assertEq(reward.token().balanceOf(address(0xaa)), 187544285714285714285714);
        vm.stopPrank();
        assertEq(reward.getClaimableAmount(address(0xaa)), 0);
    }
}

contract Reward_StartsAtMidnight is Test {
    Reward private reward;

    function setUp() public {
        vm.warp(1724198404);
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));
    }

    function test_epochStartsAtMidnight() public {
        assertEq(reward.currentEpochStart(), 1724198400);
    }
}

contract Reward_PunshItChewie is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));

        reward.addYeetVolume(address(0xaa), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
    }

    function test_userSkipsReward() public {
        assertEq(reward.getClaimableAmount(address(0xaa)), 187544285714285714285714);
        vm.startPrank(address(0xaa));
        reward.punchItChewie(2);
        vm.stopPrank();
        assertEq(reward.getClaimableAmount(address(0xaa)), 0);
    }

    function test_userCantJumpToFuture() public {
        vm.startPrank(address(0xaa));
        vm.expectRevert("Can't jump to the future");
        reward.punchItChewie(4);
        vm.stopPrank();
    }

    function test_userCantJumpToPast() public {
        vm.startPrank(address(0xaa));
        reward.claim();

        vm.expectRevert("Can't jump to the past");
        reward.punchItChewie(1);
        vm.stopPrank();
    }

    function test_userCantJumpCurrentEpoch() public {
        vm.startPrank(address(0xaa));
        vm.expectRevert("Can't jump to the future");
        reward.punchItChewie(3);
        vm.stopPrank();
    }
}

contract Reward_OneYeetAndMultipleEpochsClaimsAvailable is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));

        reward.addYeetVolume(address(0xaa), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
    }

    function test_userHasClaimsAfterEndOfTwoEpoch() public {
        assertEq(reward.getClaimableAmount(address(0xaa)), 187544285714285714285714);
    }

    function test_userHasClaimsThatAccumulateAfterEndOfTwoEpoch() public {
        skip(86402);
        reward.addYeetVolume(address(0xaa), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);
        assertEq(reward.getClaimableAmount(address(0xaa)), 375088571428571428571428);
    }
}

contract Reward_OneYeetAndMultipleEpochsClaims is Test {
    Reward private reward;
    MockERC20 private token;

    function setUp() public {
        token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));

        reward.addYeetVolume(address(0xaa), 1000);
        skip(86402);
        reward.addYeetVolume(address(0xaa), 1000);
    }

    function test_userClaimsAndYeetsInSameEpoch() public {
        assertEq(token.balanceOf(address(0xaa)), 0);

        vm.startPrank(address(0xaa));
        reward.claim();
        vm.stopPrank();

        assertEq(token.balanceOf(address(0xaa)), 187544285714285714285714, "User should have x tokens");
        assertEq(reward.getClaimableAmount(address(0xaa)), 0, "User should have no claimable amount");

        assertEq(reward.currentEpoch(), 2);
        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);

        assertEq(reward.currentEpoch(), 3, "Current epoch should be 3");
        assertEq(reward.getClaimableAmount(address(0xaa)), 187544285714285714285714, "User should have x tokens 2");

        vm.startPrank(address(0xaa));
        reward.claim();
        vm.stopPrank();

        assertEq(reward.getClaimableAmount(address(0xaa)), 0 * (10 ** 18), "User should have no claimable amount 2");
        assertEq(
            reward.token().balanceOf(address(0xaa)), 375088571428571428571428, "User should have 551_600 tokens"
        );
    }
}

contract Reward_Rewards_CappedPerUserPerEpoch is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(10);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));
    }

    function test_shouldCapRewardsAt10Percent() public {
        reward.addYeetVolume(address(0xaa), 1000);

        skip(86402);
        reward.addYeetVolume(address(0xbb), 1000);

        assertEq(reward.getClaimableAmount(address(0xaa)), 18754428571428571428571);
    }
}

contract Reward_runFor208weeks is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 40_000_000 * (10 ** 18));
    }

    function test_runFor208weeks() public {
        uint256 nrOfDays = 208 * 7;
        for (uint256 i = 0; i < nrOfDays; i++) {
            reward.addYeetVolume(address(0xaa), 1000);
            skip(86402);
        }
        assertApproxEqRel(reward.getClaimableAmount(address(0xaa)), 170_000_000 ether, 1 ether / 1000);
    }
}

contract Reward_clawback is Test {
    Reward private reward;

    function setUp() public {
        MockERC20 token = new MockERC20("TEST", "TEST", 18);
        RewardSettings settings = new RewardSettings();
        settings.setYeetRewardsSettings(1);
        reward = new Reward(token, settings);
        reward.setYeetContract(address(this));

        token.mint(address(reward), 400_000_000 * (10 ** 18));
    }

    function test_clawback() public {
        require(
            reward.token().balanceOf(address(reward)) == 400_000_000 * (10 ** 18),
            "Reward contract should have 40_000_000 tokens"
        );
        uint256 nrOfDays = 207 * 7;
        for (uint256 i = 0; i < nrOfDays; i++) {
            reward.addYeetVolume(address(0xaa), 1000);
            skip(86402);
        }
        vm.startPrank(address(0xaa));
        reward.claim();
        vm.stopPrank();
        uint256 tokenBalance = reward.token().balanceOf(address(reward));
        assertEq(tokenBalance, 230531904049126386752758165, "Reward contract should have correct tokens");
        reward.clawbackTokens(tokenBalance);
        require(reward.token().balanceOf(address(reward)) == 0, "Reward contract should have 40_000_000 tokens");
        require(reward.token().balanceOf(address(this)) == tokenBalance, "User should have clawback tokens tokens");
    }
}
