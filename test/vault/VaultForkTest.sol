// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "forge-std/console.sol";

import {IZapper} from "../../src/interfaces/IZapper.sol";
import {IOBRouter} from "../../src/interfaces/oogabooga/IOBRouter.sol";
import {ForkTest} from "../ForkTest.sol";
import {IKodiakVaultV1} from "../../src/interfaces/kodiak/IKodiakVaultV1.sol";
import {ForkTest, Contracts} from "../ForkTest.sol";
import "../../src/interfaces/beradrome/IPlugin.sol";
import "../../src/interfaces/beradrome/IGauge.sol";
import "../../src/interfaces/kodiak/IKodiakRewards.sol";
import "../../src/interfaces/kodiak/IXKdkTokenUsage.sol";
import "../../src/interfaces/kodiak/IXKdkToken.sol";

struct BeradromeRewardTokens {
    uint256 kdk;
    uint256 xKdk;
    uint256 oBero;
}

struct VaultData {
    uint256 totalAssets;
    uint256 totalShares;
}

contract VaultForkTest is ForkTest {
    function initContracts(uint256 forkBlockNumber) public virtual {
        initializeContracts(forkBlockNumber);
    }

    function getMaxIslandMintTokens(uint256 amount0Max, uint256 amount1Max)
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 mintAmount)
    {
        (amount0, amount1, mintAmount) = contracts.yeetIsland.getMintAmounts(amount0Max, amount1Max);
    }

    // amount0 is for token0 from yeetIsland -> 0x1740F679325ef3686B2f574e392007A92e4BeD41 (Yeet)
    // amount1 is for token1 from yeetIsland -> 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8 (Wbera)
    function depositIntoYeetIsland(address user, uint256 _amount0, uint256 _amount1)
        public
        returns (uint256 amount0, uint256 amount1, uint256 mintAmount)
    {
        (amount0, amount1, mintAmount) = getMaxIslandMintTokens(_amount0, _amount1);
        vm.prank(user);
        IERC20(yeet).approve(KodiakRouterStakingV1, amount0);
        vm.prank(user);
        IERC20(Wbera).approve(KodiakRouterStakingV1, amount1);

        uint256 initalBalance = contracts.yeetIsland.balanceOf(user);
        vm.prank(user);
        contracts.kodiakStakingRouter.addLiquidity(
            contracts.yeetIsland,
            _amount0,
            _amount1, // @todo try with min as well.
            amount0,
            amount1,
            mintAmount,
            user
        );
        uint256 finalBalance = contracts.yeetIsland.balanceOf(user);
        // verify minted amount with balance
        assertEq(mintAmount, finalBalance - initalBalance);
    }

    struct UserState {
        uint256 shares;
        uint256 assets;
        uint256 yeetBalance;
        uint256 wBeraBalance;
    }

    struct VaultState {
        uint256 totalAssets;
        uint256 totalShares;
    }

    struct DepositResult {
        uint256 yeetUsed;
        uint256 wBeraUsed;
        uint256 islandsMinted;
        uint256 sharesMinted;
    }

    function getUserState(address user) private view returns (UserState memory) {
        return UserState({
            shares: IERC4626(moneyBrinter).balanceOf(user),
            yeetBalance: IERC20(yeet).balanceOf(user),
            wBeraBalance: IERC20(Wbera).balanceOf(user),
            assets: IERC20(yeetIsland).balanceOf(user)
        });
    }

    function getVaultState() private view returns (VaultState memory) {
        return VaultState({
            totalAssets: IERC4626(moneyBrinter).totalAssets(),
            totalShares: IERC4626(moneyBrinter).totalSupply()
        });
    }

    function performDeposit(address user, address receiver, uint256 yeetAmount, uint256 wBeraAmount)
        private
        returns (DepositResult memory)
    {
        (uint256 yeetUsed, uint256 wBeraUsed, uint256 islandsMinted) =
            depositIntoYeetIsland(user, yeetAmount, wBeraAmount);
        vm.prank(user);
        IERC20(yeetIsland).approve(moneyBrinter, islandsMinted);
        uint256 shares = IERC4626(moneyBrinter).previewDeposit(islandsMinted);
        vm.expectEmit(true, true, true, true, beradromeFarmPlugin);
        emit IPlugin.Plugin__Deposited(moneyBrinter, islandsMinted);
        vm.expectEmit(true, true, true, true, moneyBrinter);
        emit IERC4626.Deposit(user, user, islandsMinted, shares);
        vm.prank(user);
        uint256 sharesMinted = IERC4626(moneyBrinter).deposit(islandsMinted, receiver);
        return DepositResult({
            yeetUsed: yeetUsed,
            wBeraUsed: wBeraUsed,
            islandsMinted: islandsMinted,
            sharesMinted: sharesMinted
        });
    }

    function depositIntoVaultAndVerify(uint256 yeetAmount, uint256 wBeraAmount, address depositor, address receiver)
        public
        returns (uint256, uint256)
    {
        fundYeet(depositor, yeetAmount);
        fundWbera(depositor, wBeraAmount);
        UserState memory initialDepositerState = getUserState(depositor);
        UserState memory initialReceiverState = getUserState(depositor);
        VaultState memory initialVaultState = getVaultState();
        DepositResult memory result = performDeposit(depositor, receiver, yeetAmount, wBeraAmount);
        UserState memory finalDepositerState = getUserState(depositor);
        UserState memory finalReceiverState = getUserState(receiver);
        VaultState memory finalVaultState = getVaultState();
        verifyDeposit(
            initialDepositerState,
            finalDepositerState,
            initialReceiverState,
            finalReceiverState,
            initialVaultState,
            finalVaultState,
            result
        );
        return (result.islandsMinted, result.sharesMinted);
    }

    function verifyDeposit(
        UserState memory initialDepositorState,
        UserState memory finalDepositorState,
        UserState memory initialReceiverState,
        UserState memory finalReceiverState,
        VaultState memory initialVaultState,
        VaultState memory finalVaultState,
        DepositResult memory result
    ) private view {
        assertEq(
            finalReceiverState.shares - initialReceiverState.shares,
            result.sharesMinted,
            "Deposit: Invalid shares minted"
        );
        assertEq(
            finalVaultState.totalShares - initialVaultState.totalShares,
            result.sharesMinted,
            "Deposit: Invalid shares minted"
        );
        assertEq(
            initialDepositorState.yeetBalance - finalDepositorState.yeetBalance,
            result.yeetUsed,
            "Deposit: Invalid yeet amount"
        );
        assertEq(
            initialDepositorState.wBeraBalance - finalDepositorState.wBeraBalance,
            result.wBeraUsed,
            "Deposit: Invalid wBera amount"
        );
        verifyVaultAssets(initialVaultState.totalAssets + result.islandsMinted);
    }

    // function depositIntoVaultAndVerify(uint yeetAmount, uint wBeraAmount, address user, address receiver) public returns (uint, uint) {
    //     fundYeet(user, yeetAmount);
    //     fundWbera(user, wBeraAmount);
    //     // Fund user
    //     UserState memory initialUserState = UserState({
    //         shares: IERC4626(moneyBrinter).balanceOf(user),
    //         yeetBalance: IERC20(yeet).balanceOf(user),
    //         wBeraBalance: IERC20(Wbera).balanceOf(user),
    //         assets: IERC20(yeetIsland).balanceOf(user)
    //     });
    //     VaultState memory initialVaultState = VaultState({totalAssets: IERC4626(moneyBrinter).totalAssets(), totalShares: IERC4626(moneyBrinter).totalSupply()});
    //     // Mint LP tokens
    //     (uint yeetUsed, uint wBeraUsed, uint islandsMinted) = depositIntoYeetIsland(user, yeetAmount, wBeraAmount);
    //     // Deposit into vault
    //     vm.prank(user);
    //     IERC20(yeetIsland).approve(moneyBrinter, islandsMinted);
    //     uint shares = IERC4626(moneyBrinter).previewDeposit(islandsMinted);
    //     vm.expectEmit(true, true, true, true, beradromeFarmPlugin);
    //     emit IPlugin.Plugin__Deposited(moneyBrinter, islandsMinted);
    //     vm.expectEmit(true, true, true, true, moneyBrinter);
    //     emit IERC4626.Deposit(user, user, islandsMinted, shares);

    //     vm.prank(user);
    //     uint sharesMinted = IERC4626(moneyBrinter).deposit(islandsMinted, receiver);

    //     UserState memory finalUserState = UserState({
    //         shares: IERC4626(moneyBrinter).balanceOf(receiver),
    //         yeetBalance: IERC20(yeet).balanceOf(user),
    //         assets: IERC20(yeetIsland).balanceOf(user),
    //         wBeraBalance: IERC20(Wbera).balanceOf(user)
    //     });

    //     VaultState memory finalVaultState = VaultState({totalAssets: IERC4626(moneyBrinter).totalAssets(), totalShares: IERC4626(moneyBrinter).totalSupply()});
    //     // console.log(finalUserState.shares, finalUserState.assets, finalUserState.yeetBalance, finalUserState.wBeraBalance);
    //     // Assertions
    //     assertEq(finalUserState.shares - initialUserState.shares, sharesMinted, "Deposit: Invalid shares minted");
    //     // console.log("0", finalVaultState.totalShares, initialVaultState.totalShares);
    //     assertEq(finalVaultState.totalShares - initialVaultState.totalShares, sharesMinted, "Deposit: Invalid shares minted");
    //     // console.log("1", finalVaultState.totalShares, initialVaultState.totalShares);
    //     // console.log("2", initialUserState.yeetBalance, finalUserState.yeetBalance);
    //     assertEq(initialUserState.yeetBalance - finalUserState.yeetBalance, yeetUsed, "Deposit: Invalid yeet amount");
    //     // // console.log("3", initialUserState.wBeraBalance, finalUserState.wBeraBalance, wBeraUsed);
    //     assertEq(initialUserState.wBeraBalance - finalUserState.wBeraBalance, wBeraUsed, "Deposit: Invalid wBera amount");
    //     verifyVaultAssets(initialVaultState.totalAssets + islandsMinted);
    //     return (islandsMinted, sharesMinted);
    // }

    function redeemFromVaultAndVerify(
        address sender,
        address _owner,
        address receiver,
        uint256 shares,
        uint256 expectedIslandOut
    ) public returns (uint256, uint256) {
        UserState memory ownerInitialState = UserState({
            shares: IERC4626(moneyBrinter).balanceOf(_owner),
            assets: IERC20(yeetIsland).balanceOf(_owner),
            yeetBalance: IERC20(yeet).balanceOf(_owner),
            wBeraBalance: IERC20(Wbera).balanceOf(_owner)
        });
        UserState memory receiverInitialState = UserState({
            shares: IERC4626(moneyBrinter).balanceOf(receiver),
            assets: IERC20(yeetIsland).balanceOf(receiver),
            yeetBalance: IERC20(yeet).balanceOf(receiver),
            wBeraBalance: IERC20(Wbera).balanceOf(receiver)
        });
        VaultState memory initialVaultState = VaultState({
            totalAssets: IERC4626(moneyBrinter).totalAssets(),
            totalShares: IERC4626(moneyBrinter).totalSupply()
        });
        uint256 expectedAssetOut = IERC4626(moneyBrinter).previewRedeem(shares);

        vm.expectEmit(true, true, true, true, beradromeFarmPlugin);
        emit IPlugin.Plugin__Withdrawn(moneyBrinter, expectedIslandOut);
        vm.expectEmit(true, true, true, true, moneyBrinter);
        emit IERC4626.Withdraw(sender, receiver, _owner, expectedIslandOut, shares);
        vm.prank(sender);
        uint256 assetOut = IERC4626(moneyBrinter).redeem(shares, receiver, _owner);

        UserState memory ownerFinalState = UserState({
            shares: IERC4626(moneyBrinter).balanceOf(_owner),
            assets: IERC20(yeetIsland).balanceOf(_owner),
            yeetBalance: IERC20(yeet).balanceOf(_owner),
            wBeraBalance: IERC20(Wbera).balanceOf(_owner)
        });
        UserState memory receiverFinalState = UserState({
            shares: IERC4626(moneyBrinter).balanceOf(receiver),
            assets: IERC20(yeetIsland).balanceOf(receiver),
            yeetBalance: IERC20(yeet).balanceOf(receiver),
            wBeraBalance: IERC20(Wbera).balanceOf(receiver)
        });
        VaultState memory finalVaultState = VaultState({
            totalAssets: IERC4626(moneyBrinter).totalAssets(),
            totalShares: IERC4626(moneyBrinter).totalSupply()
        });
        assertEq(ownerInitialState.shares - ownerFinalState.shares, shares, "Withdraw: Invalid owner shares burned");
        assertEq(receiverFinalState.assets - receiverInitialState.assets, assetOut, "Withdraw: Invalid assets received");
        assertEq(
            initialVaultState.totalAssets - finalVaultState.totalAssets,
            expectedAssetOut,
            "Withdraw: Invalid islands amount received"
        );
        return (shares, assetOut);
    }

    function verifyVaultAssets(uint256 expectedTotalAssets) public view {
        vm.assertEq(
            IERC4626(moneyBrinter).totalAssets(),
            contracts.beradromeFarmPlugin.balanceOf(moneyBrinter),
            "Beradrome Integration Error: totalAssets do not match"
        );
        vm.assertEq(
            IERC4626(moneyBrinter).totalAssets(), expectedTotalAssets, "expected totalAssets = current totalAssets"
        );
    }

    // Helper functions listed below.

    function _getVaultData() internal view returns (VaultData memory) {
        return VaultData({
            totalAssets: IERC4626(moneyBrinter).totalAssets(),
            totalShares: IERC4626(moneyBrinter).totalSupply()
        });
    }

    function _getRewardsEarned(address account) internal view returns (BeradromeRewardTokens memory) {
        return BeradromeRewardTokens({
            kdk: contracts.beradromeFarmRewardsGauge.earned(account, kdk),
            xKdk: contracts.beradromeFarmRewardsGauge.earned(account, xKdk),
            oBero: contracts.beradromeFarmRewardsGauge.earned(account, oBero)
        });
    }

    function _getRewardTokenBalance(address account) internal view returns (BeradromeRewardTokens memory) {
        return BeradromeRewardTokens({
            kdk: IERC20(kdk).balanceOf(account),
            xKdk: IERC20(xKdk).balanceOf(account),
            oBero: IERC20(oBero).balanceOf(account)
        });
    }

    function _makeMultipleDeposits(uint256 maxYeet, uint256 maxWBera) internal {
        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
        depositIntoVaultAndVerify(maxYeet, maxWBera, bob, bob);
        depositIntoVaultAndVerify(maxYeet, maxWBera, charlie, charlie);
    }

    function _verifyKodiakRewardHarvest(
        address[] memory rewardTokens,
        uint256[] memory earnedBefore,
        uint256[] memory pendingRewardsAfterHarvest,
        uint256[] memory vaultBalanceBefore,
        uint256[] memory vaultBalanceAfter
    ) internal pure {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertGt(vaultBalanceAfter[i] - vaultBalanceBefore[i], 0, "No Rewards accumulated");
            assertEq(vaultBalanceAfter[i] - vaultBalanceBefore[i], earnedBefore[i], "BeradromeRewardTokens not claimed");
            assertEq(pendingRewardsAfterHarvest[i], 0, "Pending rewards should be 0 after harvest");
        }
    }

    function _verifyBeradromeRewardsHarvest(
        uint256 xKdkInitialAllocation,
        BeradromeRewardTokens memory initialRewards,
        BeradromeRewardTokens memory finalRewards,
        BeradromeRewardTokens memory vaultBalancesInitial,
        BeradromeRewardTokens memory vaultBalancesFinal
    ) internal view {
        // final rewards should be zero
        // vault balances should be increased by initial rewards
        assertEq(vaultBalancesFinal.kdk - vaultBalancesInitial.kdk, initialRewards.kdk);
        if (contracts.moneyBrinter.allocateXKDKToKodiakRewards()) {
            // verify increase in allocated xKDK
            uint256 xKDKFinalAllocation = IXKdkToken(xKdk).usageAllocations(moneyBrinter, kodiakRewards);
            assertEq(xKDKFinalAllocation - xKdkInitialAllocation, initialRewards.xKdk, "xKDK not allocated on harvest");
        } else {
            assertEq(vaultBalancesFinal.xKdk - vaultBalancesInitial.xKdk, initialRewards.xKdk);
        }
        assertEq(vaultBalancesFinal.oBero - vaultBalancesInitial.oBero, initialRewards.oBero);
        assertEq(finalRewards.kdk, 0, "KDK rewards not claimed");
        assertEq(finalRewards.xKdk, 0, "xKDK rewards not claimed");
        assertEq(finalRewards.oBero, 0, "oBero rewards not claimed");
    }

    // wBera and yeet might increase due to island staking
    function _verifyCompound(
        uint256 minAssetsRecvd,
        uint256 compoundAmount,
        VaultData memory initialVaultData,
        VaultData memory finalVaultData
    ) internal view {
        assertGe(compoundAmount, minAssetsRecvd, "Compound amount should be greater than minAssetsRecvd");
        // vault total assets are increased by a min of minAssetsRecvd
        assertEq(
            finalVaultData.totalAssets - initialVaultData.totalAssets,
            compoundAmount,
            "Vault assets not increased by minAssetsRecvd"
        );
        // shares are unchanged
        assertEq(finalVaultData.totalShares, initialVaultData.totalShares, "Vault shares should not change");
        address[] memory swapInputTokens = new address[](2);
        swapInputTokens[0] = yeet;
        swapInputTokens[1] = Wbera;
        assertGe(IERC20(yeet).balanceOf(zapper), 0, "Unused Yeet not returned to vault");
        assertGe(IERC20(Wbera).balanceOf(zapper), 0, "Unused WBera not returned to vault");
    }

    function _getVaultTokenBalances(address[] memory tokens) internal view returns (uint256[] memory balances) {
        uint256 tokensLength = tokens.length;
        balances = new uint256[](tokensLength);
        for (uint256 i = 0; i < tokensLength; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(moneyBrinter);
        }
    }

    function _getPendingKodiakRewardsForVault(address[] memory rewardTokens)
        internal
        view
        returns (uint256[] memory pendingAmount)
    {
        uint256 tokensLength = contracts.kodiakRewards.distributedTokensLength();
        pendingAmount = new uint256[](tokensLength);
        for (uint256 i = 0; i < tokensLength; i++) {
            pendingAmount[i] = contracts.kodiakRewards.pendingRewardsAmount(rewardTokens[i], moneyBrinter);
        }
    }

    function _getPendingBeradromeRewards() internal view returns (BeradromeRewardTokens memory) {
        return BeradromeRewardTokens({
            kdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, kdk),
            xKdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, xKdk),
            oBero: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, oBero)
        });
    }

    function _getKodiakRewardTokens() internal view returns (address[] memory rewardTokens) {
        uint256 tokensLength = contracts.kodiakRewards.distributedTokensLength();
        rewardTokens = new address[](tokensLength);
        for (uint256 i = 0; i < tokensLength; i++) {
            rewardTokens[i] = contracts.kodiakRewards.distributedToken(i);
        }
        return rewardTokens;
    }

    function simulateVaultProfit(uint256 amount, bool isPositive) internal {
        if (amount == 0) return;
        if (isPositive) {
            vm.prank(assetWhale);
            IERC20(yeetIsland).approve(beradromeFarmPlugin, amount);
            vm.prank(assetWhale);
            contracts.beradromeFarmPlugin.depositFor(moneyBrinter, amount);
        } else {
            uint256 bal = contracts.beradromeFarmPlugin.balanceOf(moneyBrinter);
            vm.prank(moneyBrinter);
            console.log("Current balance of MoneyBrinter: ", bal, amount);
            // check balance. then check withdraw
            contracts.beradromeFarmPlugin.withdrawTo(bob, amount);
        }
    }
}
