// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZapper} from "../../src/interfaces/IZapper.sol";
import {IOBRouter} from "../../src/interfaces/oogabooga/IOBRouter.sol";
import {ForkTest} from "../ForkTest.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IKodiakVaultV1} from "../../src/interfaces/kodiak/IKodiakVaultV1.sol";
import "forge-std/console.sol";

contract ZapperForkTest is ForkTest {
    // Add these helper functions to your ZapIn contract

    function initContracts(uint256 forkBlockNumber) public virtual {
        initializeContracts(forkBlockNumber);
    }

    function prepareSwapInfo(
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        address executor,
        bytes memory path
    ) public pure returns (IZapper.SingleTokenSwap memory) {
        return IZapper.SingleTokenSwap({
            inputAmount: inputAmount,
            outputQuote: outputQuote,
            outputMin: outputMin,
            executor: executor,
            path: path
        });
    }

    function prepareStakingParams(uint256 amount0Max, uint256 amount1Max, uint256 amount0Min, uint256 amount1Min)
        public
        view
        returns (IZapper.KodiakVaultStakingParams memory params, uint256 minVaultShares)
    {
        (,, uint256 _mintAmount) = contracts.yeetIsland.getMintAmounts(amount0Min, amount1Min);
        params = IZapper.KodiakVaultStakingParams({
            kodiakVault: address(yeetIsland),
            amount0Max: amount0Max,
            amount1Max: amount1Max,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            amountSharesMin: _mintAmount,
            receiver: zapper
        });
        minVaultShares = IERC4626(moneyBrinter).previewDeposit(_mintAmount);
    }

    function prepareVaultParams(uint256 _minShares, address _receiver)
        public
        view
        returns (IZapper.VaultDepositParams memory)
    {
        return IZapper.VaultDepositParams({vault: moneyBrinter, receiver: _receiver, minShares: _minShares});
    }

    function fundAndApprove(address token, address user, uint256 amount) public {
        if (token == Wbera) {
            fundWbera(user, amount);
        } else if (token == yeet) {
            fundYeet(user, amount);
        } else if (token == honey) {
            fundHoney(user, amount);
            vm.prank(admin);
            contracts.zapper.updateSwappableTokens(honey, true);
        }
        vm.prank(user);
        IERC20(token).approve(zapper, amount);
    }

    function zapInToken0(
        address user,
        IZapper.SingleTokenSwap memory swapInfo,
        IZapper.KodiakVaultStakingParams memory stakingParams,
        IZapper.VaultDepositParams memory vaultParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256, uint256) {
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapInToken0(swapInfo, stakingParams, vaultParams);
        } else {
            if (bytes(errorMessage).length > 0) {
                vm.expectRevert(bytes(errorMessage));
            } else {
                vm.expectRevert();
            }
            vm.prank(user);
            contracts.zapper.zapInToken0(swapInfo, stakingParams, vaultParams);
            return (0, 0);
        }
    }

    function zapInToken1(
        address user,
        IZapper.SingleTokenSwap memory swapInfo,
        IZapper.KodiakVaultStakingParams memory stakingParams,
        IZapper.VaultDepositParams memory vaultParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256, uint256) {
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapInToken1(swapInfo, stakingParams, vaultParams);
        } else {
            if (bytes(errorMessage).length > 0) {
                vm.expectRevert(bytes(errorMessage));
            } else {
                vm.expectRevert();
            }
            vm.prank(user);
            contracts.zapper.zapInToken1(swapInfo, stakingParams, vaultParams);
            return (0, 0);
        }
    }

    function zapIn(
        address user,
        address inputToken,
        uint256 totalAmount,
        IZapper.SingleTokenSwap memory swapInfo0,
        IZapper.SingleTokenSwap memory swapInfo1,
        IZapper.KodiakVaultStakingParams memory stakingParams,
        IZapper.VaultDepositParams memory vaultParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256, uint256) {
        fundAndApprove(inputToken, user, totalAmount);
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapIn(inputToken, swapInfo0, swapInfo1, stakingParams, vaultParams);
        } else {
            vm.expectRevert(bytes(errorMessage));
            vm.prank(user);
            contracts.zapper.zapIn(inputToken, swapInfo0, swapInfo1, stakingParams, vaultParams);
            return (0, 0);
        }
    }

    function zapInNative(
        address user,
        uint256 totalAmount,
        IZapper.SingleTokenSwap memory swapInfo0,
        IZapper.SingleTokenSwap memory swapInfo1,
        IZapper.KodiakVaultStakingParams memory stakingParams,
        IZapper.VaultDepositParams memory vaultParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256, uint256) {
        vm.deal(user, totalAmount * 2);
        if (shouldSucceed) {
            vm.prank(user);
            return
                contracts.zapper.zapInNative{value: totalAmount * 2}(swapInfo0, swapInfo1, stakingParams, vaultParams);
        } else {
            vm.expectRevert(bytes(errorMessage));
            vm.prank(user);
            contracts.zapper.zapInNative{value: totalAmount * 2}(swapInfo0, swapInfo1, stakingParams, vaultParams);
            return (0, 0);
        }
    }

    // Zap out utils
    function prepareUnstakeParams(uint256 amount0Min, uint256 amount1Min, address receiver)
        public
        view
        returns (IZapper.KodiakVaultUnstakingParams memory)
    {
        return IZapper.KodiakVaultUnstakingParams({
            kodiakVault: yeetIsland,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            receiver: receiver
        });
    }

    function prepareVaultRedeemAndUnstakeParams(
        address vault,
        uint256 shares,
        uint256 maxSlippageVault,
        uint256 amountOut0,
        uint256 amountOut1,
        uint256 maxLPSlippage,
        address assetsReceiver,
        address lpTokenReceiver
    ) public view returns (IZapper.VaultRedeemParams memory, IZapper.KodiakVaultUnstakingParams memory) {
        // preview assets recvd from vault
        uint256 assets = IERC4626(vault).previewRedeem(shares);
        // allow 1% slippage
        uint256 minAssets = assets - ((maxSlippageVault * assets) / 10000);
        IZapper.VaultRedeemParams memory data =
            IZapper.VaultRedeemParams({vault: vault, shares: shares, minAssets: minAssets, receiver: assetsReceiver});

        uint256 minAmountOut0 = amountOut0 - ((maxLPSlippage * amountOut0) / 10000);
        uint256 minAmountOut1 = amountOut1 - ((maxLPSlippage * amountOut1) / 10000);
        // Decode the return data
        IZapper.KodiakVaultUnstakingParams memory unstakeParams =
            prepareUnstakeParams(minAmountOut0, minAmountOut1, lpTokenReceiver);
        return (data, unstakeParams);
    }

    function zapOutToToken0(
        address user,
        IZapper.SingleTokenSwap memory swapData,
        IZapper.KodiakVaultUnstakingParams memory unstakeParams,
        IZapper.VaultRedeemParams memory redeemParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256) {
        approveVaultTokens(user, moneyBrinter, redeemParams.shares);
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapOutToToken0(user, swapData, unstakeParams, redeemParams);
        } else {
            vm.expectRevert(bytes(errorMessage));
            vm.prank(user);
            contracts.zapper.zapOutToToken0(user, swapData, unstakeParams, redeemParams);
            return 0;
        }
    }

    function zapOutToToken1(
        address user,
        IZapper.SingleTokenSwap memory swapData,
        IZapper.KodiakVaultUnstakingParams memory unstakeParams,
        IZapper.VaultRedeemParams memory redeemParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256) {
        approveVaultTokens(user, moneyBrinter, redeemParams.shares);
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapOutToToken1(user, swapData, unstakeParams, redeemParams);
        } else {
            vm.expectRevert(bytes(errorMessage));
            vm.prank(user);
            contracts.zapper.zapOutToToken1(user, swapData, unstakeParams, redeemParams);
            return 0;
        }
    }

    function zapOutNative(
        address user,
        IZapper.SingleTokenSwap memory swapData0,
        IZapper.SingleTokenSwap memory swapData1,
        IZapper.KodiakVaultUnstakingParams memory unstakeParams,
        IZapper.VaultRedeemParams memory redeemParams,
        bool shouldSucceed,
        string memory errorMessage
    ) public returns (uint256) {
        approveVaultTokens(user, moneyBrinter, redeemParams.shares);
        if (shouldSucceed) {
            vm.prank(user);
            return contracts.zapper.zapOutNative(user, swapData0, swapData1, unstakeParams, redeemParams);
        } else {
            vm.expectRevert(bytes(errorMessage));
            vm.prank(user);
            contracts.zapper.zapOutNative(user, swapData0, swapData1, unstakeParams, redeemParams);
            return 0;
        }
    }

    function zapOut(
        bool shouldFail,
        string memory errorMessage,
        address user,
        address outputToken,
        IZapper.SingleTokenSwap memory swap0,
        IZapper.SingleTokenSwap memory swap1,
        IZapper.KodiakVaultUnstakingParams memory unstakeParams,
        IZapper.VaultRedeemParams memory redeemParams
    ) public returns (uint256) {
        approveVaultTokens(user, moneyBrinter, redeemParams.shares);
        if (shouldFail) {
            vm.prank(user);
            vm.expectRevert(bytes(errorMessage));
            contracts.zapper.zapOut(outputToken, user, swap0, swap1, unstakeParams, redeemParams);
            return 0;
        } else {
            vm.prank(user);
            return contracts.zapper.zapOut(outputToken, user, swap0, swap1, unstakeParams, redeemParams);
        }
    }

    // Helper function to approve vault tokens for zapping out
    function approveVaultTokens(address user, address vault, uint256 amount) public {
        vm.prank(user);
        IERC20(vault).approve(address(contracts.zapper), amount);
    }

    function verifyMinOutputTokens(
        address outputToken,
        uint256 minAmount0,
        uint256 minAmount1,
        IZapper.SingleTokenSwap memory swap0,
        IZapper.SingleTokenSwap memory swap1,
        uint256 actual
    ) public view {
        uint256 totalExpected = 0;
        if (outputToken == Wbera) {
            totalExpected += minAmount1;
            totalExpected += swap0.outputMin;
        } else if (outputToken == yeet) {
            totalExpected += minAmount0;
            totalExpected += swap1.outputMin;
        } else {
            totalExpected += swap0.outputMin + swap1.outputMin;
        }
        // find expected using swap data.
        vm.assertGt(actual, totalExpected, "Actual output is less than expected");
    }

    function verifyNoBalanceInZapper() public view {
        vm.assertEq(IERC20(yeet).balanceOf(zapper), 0, "yeet balance in zapper is not 0");
        vm.assertEq(IERC20(Wbera).balanceOf(zapper), 0, "Wbera balance in zapper is not 0");
        vm.assertEq(IERC20(honey).balanceOf(zapper), 0, "honey balance in zapper is not 0");
        vm.assertEq(IERC20(kdk).balanceOf(zapper), 0, "kdk balance in zapper is not 0");
        vm.assertEq(IERC20(oBero).balanceOf(zapper), 0, "oBero balance in zapper is not 0");
        vm.assertEq(moneyBrinter.balance, 0, "moneyBrinter balance in zapper is not 0");
    }
}
