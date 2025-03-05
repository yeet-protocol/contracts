// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VaultUnitTest.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract VaultWithdrawTest is VaultUnitTest {
    function setUp() public {
        initializeAddresses();
        initializeVault(owner, 0);
        uint256 initialBalance = 1_000_000 ether;
        fundUser(bob, initialBalance);
        _depositToVault(bob, initialBalance);
    }

    function testWithdrawInsufficientBalance() public {
        uint256 bobAssets = vault.previewRedeem(vault.balanceOf(bob));
        bytes memory expectedError =
            abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxWithdraw.selector, bob, bobAssets + 1, bobAssets);
        withdrawFromVaultAndVerify(bob, bobAssets + 1, 0, 0, 0, false, expectedError);
    }

    function testWithdrawSuccessWithFee() public {
        uint256 feeBps = 100; // 1%
        _setExitFee(feeBps);

        uint256 withdrawAmount = 100 ether;
        uint256 expectedFee = _feeOnRaw(withdrawAmount, feeBps);
        uint256 expectedAssets = withdrawAmount;
        uint256 expectedShares = vault.previewWithdraw(withdrawAmount);

        withdrawFromVaultAndVerify(bob, withdrawAmount, expectedAssets, expectedShares, expectedFee, true, "");
    }

    function testWithdrawSuccessNoFee() public {
        uint256 withdrawAmount = 100 ether;
        uint256 expectedAssets = withdrawAmount;
        uint256 expectedShares = vault.previewWithdraw(withdrawAmount);
        withdrawFromVaultAndVerify(bob, withdrawAmount, expectedAssets, expectedShares, 0, true, "");
    }
}

contract VaultRedeemTest is VaultUnitTest {
    function setUp() public {
        initializeAddresses();
        initializeVault(owner, 0);
        uint256 initialBalance = 1_000_000 ether;
        fundUser(bob, initialBalance);
        _depositToVault(bob, initialBalance);
    }

    function testRedeemInsufficientBalance() public {
        uint256 bobBalance = vault.balanceOf(bob);

        redeemFromVaultAndVerify(
            bob,
            bobBalance + 1,
            0,
            0,
            false,
            abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxRedeem.selector, bob, bobBalance + 1, bobBalance)
        );
    }

    function testRedeemSuccessNoFee() public {
        uint256 redeemAmount = 100 ether;
        uint256 expectedAssets = vault.previewRedeem(redeemAmount);

        redeemFromVaultAndVerify(bob, redeemAmount, expectedAssets, 0, true, "");
    }

    function testRedeemSuccessWithFee() public {
        uint256 feeBps = 100; // 1%
        _setExitFee(feeBps);

        uint256 redeemShares = 100 ether;
        uint256 expectedAssets = vault.previewRedeem(redeemShares);
        uint256 expectedFee = _feeOnRaw(expectedAssets, feeBps);

        redeemFromVaultAndVerify(bob, redeemShares, expectedAssets, expectedFee, true, "");
    }
}
