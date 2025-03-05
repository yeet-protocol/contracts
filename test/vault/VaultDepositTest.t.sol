// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IPlugin} from "../../src/interfaces/beradrome/IPlugin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VaultUnitTest.sol";

contract VaultDepositTest is VaultUnitTest {
    function setUp() public {
        initializeAddresses();
        initializeVault(owner, 0);
        uint256 initialBalance = 1_000_000 ether;
        // fund user with initial balance
        fundUser(bob, initialBalance);
    }

    function testDepositWithInsufficientBalance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, 10e6 ether);
        approveToVault(alice, depositAmount);
        depositIntoVaultAndVerify(
            alice,
            depositAmount,
            0,
            false,
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, depositAmount)
        );
    }

    function testDepositWithSufficientBalance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, 10e6 ether);
        uint256 expectedShares = vault.previewDeposit(depositAmount);
        fundUser(bob, depositAmount);
        approveToVault(bob, depositAmount);
        depositIntoVaultAndVerify(bob, depositAmount, expectedShares, true, "");
    }

    function testMintWithInsufficientBalance(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 1, 10e6 ether);
        uint256 expectedAssets = vault.previewMint(mintAmount);
        bytes memory expectedError =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(vault), 0, expectedAssets);
        mintVaultSharesAndVerify(bob, mintAmount, 0, false, expectedError);
    }

    function testMintWithSufficientBalance(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 1, 10e6 ether);
        uint256 expectedAssets = vault.previewMint(mintAmount);
        fundUser(bob, expectedAssets);
        approveToVault(bob, expectedAssets);
        mintVaultSharesAndVerify(bob, mintAmount, expectedAssets, true, "");
    }
}
