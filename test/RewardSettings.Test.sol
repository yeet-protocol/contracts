pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardSettings.sol";

contract RewardSettingsTest is Test {
    RewardSettings private rewardSettings;

    function setUp() public {
        rewardSettings = new RewardSettings();
    }

    function test_YeetRewardSettingsDefaults() public {
        assertEq(rewardSettings.MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR(), 30);
    }

    function test_ChangeYeetRewardSettings() public {
        rewardSettings.setYeetRewardsSettings(100);

        assertEq(rewardSettings.MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR(), 100);
    }
}

contract YeetGameSettingsTest_MaxCapPerWalletPerEpochFactor is Test {
    RewardSettings private rewardSettings;

    function setUp() public {
        rewardSettings = new RewardSettings();
    }

    function test_MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR_in_range() public {
        rewardSettings.setYeetRewardsSettings(1);
        rewardSettings.setYeetRewardsSettings(100);
    }

    function test_MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR_toHigh() public {
        vm.expectRevert("YeetRewardSettings: maxCapPerWalletPerEpochFactor must be less than 100");
        rewardSettings.setYeetRewardsSettings(101);
    }

    function test_MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR_toLow() public {
        vm.expectRevert("YeetRewardSettings: maxCapPerWalletPerEpochFactor must be greater than 1");
        rewardSettings.setYeetRewardsSettings(0);
    }
}
