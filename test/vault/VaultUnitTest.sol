// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MoneyBrinter} from "contracts/MoneyBrinter.sol";
import {IMoneyBrinter} from "interfaces/IMoneyBrinter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BeradromeFarmMock} from "../mocks/BeradromeFarmMock.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultUnitTest is Test {
    using Math for uint256;

    MoneyBrinter public vault;
    ERC20Mock public asset;
    BeradromeFarmMock public farmPlugin;
    address public treasury;
    address public bob;
    address public alice;
    address public owner;
    uint256 public constant _BASIS_POINT_SCALE = 10000;
    uint256 tickLength = 60 * 60; // 1 hour
    uint256 withdrawalPeriod = 4 * 60 * 60; // 4 hours
    uint256 rateLimitCooldownPeriod = 60 * 60; // 4 hours

    function _depositToVault(address depositor, uint256 amount) internal {
        vm.startPrank(depositor);
        asset.approve(address(vault), amount);
        vault.deposit(amount, depositor);
        vm.stopPrank();
    }

    function _mintVaultShares(address minter, uint256 shares) internal {
        vm.startPrank(minter);
        asset.approve(address(vault), type(uint256).max);
        vault.mint(shares, minter);
        vm.stopPrank();
    }

    function _setExitFee(uint256 newFeeBps) internal {
        vm.prank(owner);
        vault.setExitFeeBasisPoints(newFeeBps);
    }

    function fundUser(address user, uint256 amount) internal {
        asset.mint(user, amount);
    }

    function approveToVault(address user, uint256 amount) internal {
        vm.prank(user);
        asset.approve(address(vault), amount);
    }

    function depositIntoVaultAndVerify(
        address user,
        uint256 amount,
        uint256 expectedShares,
        bool shouldSuceed,
        bytes memory revertReason
    ) internal {
        if (shouldSuceed) {
            vm.prank(user);
            uint256 actualShares = vault.deposit(amount, user);
            assertEq(actualShares, expectedShares);
        } else {
            vm.expectRevert(revertReason);
            vm.prank(user);
            vault.deposit(amount, user);
        }
    }

    function mintVaultSharesAndVerify(
        address user,
        uint256 amount,
        uint256 expectedAssets,
        bool shouldSuceed,
        bytes memory revertReason
    ) internal {
        if (shouldSuceed) {
            vm.prank(user);
            uint256 actualAssets = vault.mint(amount, user);
            assertEq(actualAssets, expectedAssets);
        } else {
            vm.expectRevert(revertReason);
            vm.prank(user);
            vault.mint(amount, user);
        }
    }

    function withdrawFromVaultAndVerify(
        address user,
        uint256 amount,
        uint256 expectedAssets,
        uint256 expectedShares,
        uint256 expectedFee,
        bool shouldSucceed,
        bytes memory revertReason
    ) internal {
        if (shouldSucceed) {
            if (expectedFee > 0) {
                vm.expectEmit(true, true, true, true);
                emit IMoneyBrinter.FeeCollected(user, user, treasury, expectedFee);
            }
            vm.expectEmit(true, true, true, true);
            emit IERC4626.Withdraw(user, user, user, expectedAssets, expectedShares);
            vm.prank(user);
            vault.withdraw(amount, user, user);
        } else {
            vm.expectRevert(revertReason);
            vm.prank(user);
            vault.withdraw(amount, user, user);
        }
    }

    function redeemFromVaultAndVerify(
        address user,
        uint256 shares,
        uint256 expectedAssets,
        uint256 expectedFee,
        bool shouldSucceed,
        bytes memory revertReason
    ) internal {
        if (shouldSucceed) {
            if (expectedFee > 0) {
                vm.expectEmit(true, true, true, true);
                emit IMoneyBrinter.FeeCollected(user, user, treasury, expectedFee);
            }
            vm.expectEmit(true, true, true, true);
            emit IERC4626.Withdraw(user, user, user, expectedAssets, shares);
            vm.prank(user);
            vault.redeem(shares, user, user);
        } else {
            vm.expectRevert(revertReason);
            vm.prank(user);
            vault.redeem(shares, user, user);
        }
    }

    function initializeVault(address _owner, uint256 _exitFeeBps) internal {
        vm.startPrank(_owner);
        asset = new ERC20Mock();
        BeradromeFarmMock _farmPlugin = new BeradromeFarmMock(address(asset));
        address farmRewardsGauge = address(0x1); // this is unused in tests using this function
        vault =
            new MoneyBrinter(address(asset), "Test Vault", "TV", treasury, address(_farmPlugin), farmRewardsGauge, 2000);
        if (_exitFeeBps != 0) {
            vault.setExitFeeBasisPoints(_exitFeeBps);
        }
        vm.stopPrank();
    }

    function initializeAddresses() internal {
        owner = address(0x4);
        treasury = address(0x1);
        bob = address(0x2);
        alice = address(0x3);
    }

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }
}

//     event Redeem(address indexed userAddress, uint256 xKodiakAmount, uint256 kodiakAmount, uint256 duration);
//     event FinalizeRedeem(address indexed userAddress, uint256 xKodiakAmount, uint256 kodiakAmount);
//     event CancelRedeem(address indexed userAddress, uint256 xKodiakAmount);
//     event UpdateRedeemRewardsAddress(address indexed userAddress, uint256 redeemIndex, address previousRewardsAddress, address newRewardsAddress);
