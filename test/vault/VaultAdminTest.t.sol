// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VaultUnitTest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// import "forge-std/Test.sol";

contract VaultAdminTest is VaultUnitTest {
    function setUp() public {
        initializeAddresses();
        initializeVault(owner, 0);
    }

    function testSetTreasury_NotAdmin() public {
        address newTreasury = address(0x4);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setTreasury(newTreasury);
    }

    function testSetTreasury_Valid_Admin_ValidAddress() public {
        address newTreasury = address(0x4);
        vm.prank(owner);
        vault.setTreasury(newTreasury);
        assertEq(vault.treasury(), newTreasury);
    }

    function testSetTreasury_Valid_Admin_ZeroAddress() public {
        address newTreasury = address(0);
        vm.prank(owner);
        vm.expectRevert("MoneyBrinter: treasury cannot be zero address");
        vault.setTreasury(newTreasury);
    }

    function testSetExitFeeBasisPoints_NotAdmin() public {
        uint256 newExitFeeBps = 200; // 2%
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setExitFeeBasisPoints(newExitFeeBps);
    }

    function testSetExitFeeBasisPoints_Valid_Admin_ValidValue() public {
        uint256 newExitFeeBps = 200; // 2%
        vm.prank(owner);
        vault.setExitFeeBasisPoints(newExitFeeBps);
        assertEq(vault.exitFeeBasisPoints(), newExitFeeBps);
    }

    function testSetExitFeeBasisPoints_Valid_Admin_Exceeds_Maximum_Fee() public {
        uint256 maxAllowedFeeBps = vault.maxAllowedFeeBps();
        vm.prank(owner);
        vm.expectRevert("MoneyBrinter: feeBps too high");
        vault.setExitFeeBasisPoints(maxAllowedFeeBps + 1);
    }

    function testSetZapper_NotAdmin() public {
        address newZapper = address(0x5);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setZapper(newZapper);
    }

    function testSetZapper_Valid_Admin_ValidAddress() public {
        address newZapper = address(0x5);
        vm.prank(owner);
        vault.setZapper(newZapper);
        assertEq(address(vault.zapper()), newZapper);
    }

    function testSetZapper_Valid_Admin_ZeroAddress() public {
        address newZapper = address(0);
        vm.prank(owner);
        vm.expectRevert("MoneyBrinter: zapper cannot be zero address");
        vault.setZapper(newZapper);
    }

    function testSetStrategyManager_NotAdmin() public {
        address manager = address(0x6);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setStrategyManager(manager, true);
    }

    function testSetStrategyManager_Valid_Admin() public {
        address manager = address(0x6);
        vm.prank(owner);
        vault.setStrategyManager(manager, true);
        assertTrue(vault.strategyManager(manager));

        vm.prank(owner);
        vault.setStrategyManager(manager, false);
        assertFalse(vault.strategyManager(manager));
    }

    function testSetAllocationFlagxKDK_NotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setAllocationFlagxKDK(true);
    }

    function testSetAllocationFlagxKDK_Valid_Admin() public {
        vm.prank(owner);
        vault.setAllocationFlagxKDK(true);
        assertTrue(vault.allocateXKDKToKodiakRewards());

        vm.prank(owner);
        vault.setAllocationFlagxKDK(false);
        assertFalse(vault.allocateXKDKToKodiakRewards());
    }

    function testSetXKdk_NotAdmin() public {
        address newXKdk = address(0x8);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        vault.setXKdk(newXKdk);
    }

    function testSetXKdk_Valid_Admin_ValidAddress() public {
        address newXKdk = address(0x8);
        vm.prank(owner);
        vault.setXKdk(newXKdk);
        assertEq(vault.xKdk(), newXKdk);
    }

    function testSetXKdk_Valid_Admin_ZeroAddress() public {
        address newXKdk = address(0);
        vm.prank(owner);
        vm.expectRevert("MoneyBrinter: xKdk cannot be zero address");
        vault.setXKdk(newXKdk);
    }
}
