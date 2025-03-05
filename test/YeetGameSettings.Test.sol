pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/YeetGameSettings.sol";

contract YeetGameSettingsTest is Test {
    YeetGameSettings private yeetGameSettings;

    function setUp() public {
        yeetGameSettings = new YeetGameSettings();
    }

    function test_YeetSettingsDefaults() public {
        assertEq(yeetGameSettings.YEET_TIME_SECONDS(), 1 hours);
        assertEq(yeetGameSettings.POT_DIVISION(), 200);
    }

    function test_ChangeYeetSettings() public {
        uint256 yeetTimeSeconds = 2 hours;
        uint256 potDivision = 300;

        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );

        assertEq(yeetGameSettings.YEET_TIME_SECONDS(), yeetTimeSeconds);
        assertEq(yeetGameSettings.POT_DIVISION(), potDivision);
    }

    function test_invalid() public {
        uint256 potDivision = 300;

        uint256 yeetTimeSeconds = 30;
        vm.expectRevert("YeetGameSettings: yeetTimeSeconds must be greater than 60 seconds");

        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }
}

contract YeetGameSettingsTest_CooldownTime is Test {
    YeetGameSettings private yeetGameSettings;

    function setUp() public {
        yeetGameSettings = new YeetGameSettings();
    }

    function test_COOLDOWN_TIME_in_range() public {
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            20,
            0 days,
            0.001 ether
        );

        assertEq(yeetGameSettings.COOLDOWN_TIME(), 20);

        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            3 days,
            0 days,
            0.001 ether
        );
        assertEq(yeetGameSettings.COOLDOWN_TIME(), 3 days);
    }

    function test_COOLDOWN_TIME_toHigh() public {
        vm.expectRevert("YeetGameSettings: cooldownTime must be less than 3 day");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            3 days + 1,
            0 days,
            0.001 ether
        );
    }
}

contract YeetGameSettingsTest_YeetTimeSeconds is Test {
    YeetGameSettings private yeetGameSettings;
    uint256 private potDivision = 300;

    function setUp() public {
        yeetGameSettings = new YeetGameSettings();
    }

    function test_MINIMUM_YEET_TIME_SECONDS_in_range() public {
        yeetGameSettings.setYeetSettings(
            1 days,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
        yeetGameSettings.setYeetSettings(
            60 seconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_MINIMUM_YEET_TIME_SECONDS_toHigh() public {
        vm.expectRevert("YeetGameSettings: yeetTimeSeconds must be less than 1 day");
        uint256 yeetTimeSeconds = 1 days + 1;
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_MINIMUM_YEET_TIME_SECONDS_toLow30() public {
        vm.expectRevert("YeetGameSettings: yeetTimeSeconds must be greater than 60 seconds");
        uint256 yeetTimeSeconds = 30;
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_MINIMUM_YEET_TIME_SECONDS_toLow59() public {
        vm.expectRevert("YeetGameSettings: yeetTimeSeconds must be greater than 60 seconds");
        uint256 yeetTimeSeconds = 59;
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            potDivision,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }
}

contract YeetGameSettingsTest_PotDivision is Test {
    YeetGameSettings private yeetGameSettings;
    uint256 private yeetTimeSeconds = 1 days;
    uint256 private timeDecreaseFactor = 40;

    function setUp() public {
        yeetGameSettings = new YeetGameSettings();
    }

    function test_POT_DIVISION_in_range() public {
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            1000,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            1000,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_POT_DIVISION_toHigh() public {
        vm.expectRevert("YeetGameSettings: potDivision must be less than 1000");
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            1001,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_POT_DIVISION_toLow() public {
        vm.expectRevert("YeetGameSettings: potDivision must be greater than 10");
        yeetGameSettings.setYeetSettings(
            yeetTimeSeconds,
            9,
            1000, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }
}

contract YeetGameSettingsTest_TaxSettings is Test {
    YeetGameSettings private yeetGameSettings;

    function setUp() public {
        yeetGameSettings = new YeetGameSettings();
    }

    function test_TAX_SETTINGS_in_range() public {
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            500, // taxPerYeet
            8000, // taxToStakers
            800, // taxToPublicGoods
            1200, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );

        assertEq(yeetGameSettings.TAX_PER_YEET(), 500);
        assertEq(yeetGameSettings.TAX_TO_STAKERS(), 8000);
        assertEq(yeetGameSettings.TAX_TO_PUBLIC_GOODS(), 800);
    }

    function test_TAX_SETTINGS_toHigh() public {
        vm.expectRevert("YeetGameSettings: taxPerYeet must be less than 20%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            2100, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_toLow() public {
        vm.expectRevert("YeetGameSettings: taxToStakers must be greater than 50%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            500, // taxPerYeet
            4900, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_sum_notEqual100() public {
        vm.expectRevert("YeetGameSettings: taxToStakers + taxToPublicGoods + taxToTreasury must equal 100%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            500, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            999, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_taxPerYeet_min() public {
        vm.expectRevert("YeetGameSettings: taxPerYeet must be greater than 1%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            0, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_taxPerYeet_max() public {
        vm.expectRevert("YeetGameSettings: taxPerYeet must be less than 20%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            2100, // taxPerYeet
            7000, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_taxToStakers_min() public {
        vm.expectRevert("YeetGameSettings: taxToStakers must be greater than 50%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            4900, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_taxToStakers_max() public {
        vm.expectRevert("YeetGameSettings: taxToStakers must be less than 90%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            9100, // taxToStakers
            2000, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }

    function test_TAX_SETTINGS_taxToPublicGoods_max() public {
        vm.expectRevert("YeetGameSettings: taxToPublicGoods must be less than 20%");
        yeetGameSettings.setYeetSettings(
            1 hours,
            200,
            1000, // taxPerYeet
            7000, // taxToStakers
            2100, // taxToPublicGoods
            1000, // taxToTreasury
            2000,
            0,
            0 days,
            0.001 ether
        );
    }
}
