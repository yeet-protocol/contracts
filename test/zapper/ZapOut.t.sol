// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {ForkTest} from "../ForkTest.sol";
import {IZapper} from "../../src/interfaces/IZapper.sol";
import {ZapperForkTest} from "./ZapperForkTest.sol";

contract ZapOut is ZapperForkTest {
    uint256 public vaultShares;
    uint256 public amount0;
    uint256 public amount1;

    function setUp() public {
        uint256 forkBlockNumber = 3477196;
        super.initContracts(forkBlockNumber);
        // set fee to 0
        vm.prank(admin);
        contracts.moneyBrinter.setExitFeeBasisPoints(0);
        uint256 totalWbera = 2 ether;
        uint256 toSwap = 1 ether;
        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(
            toSwap,
            100761302310950207488,
            98746076264731203338,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );
        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(swapInfo.outputMin, totalWbera - toSwap, swapInfo.outputMin / 10, 1e17);
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);
        // approve Wbera
        fundAndApprove(Wbera, alice, 1000000 ether);
        (, uint256 _vaultShares) = zapInToken1(alice, swapInfo, stakingParams, vaultParams, true, "");
        vaultShares = _vaultShares;
        amount0 = 98746076264731203330;
        amount1 = 887270437165938108;
        // try burning shares to find out the amount0 and amount1 recvd.
        // vm.prank(alice);
        // uint assets = IERC4626(moneyBrinter).redeem(vaultShares, alice, alice);
        // console.log("Assets: ", assets);
        // // check balance
        // vm.prank(alice);
        // IERC20(yeetIsland).approve(KodiakRouterStakingV1, assets);
        // vm.prank(alice);
        // (uint a0, uint a1, uint burned) = contracts.kodiakStakingRouter.removeLiquidity(contracts.yeetIsland, assets, 0, 0, alice);
        // console.log("Amount0: ", a0);
        // console.log("Amount1: ", a1);
        // console.log("Burned: ", burned);
    }

    function test_successful_zap_out_wBera() public {
        // 1% slippage during LP redeem
        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(
            amount0,
            881023144322313440,
            863402681435867171,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD4102eaaa00f6451D031f084c96469A9887CCC520c960eaA34C01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory noSwap;
        (IZapper.VaultRedeemParams memory vaultParams, IZapper.KodiakVaultUnstakingParams memory islandUnstakingParams)
        = prepareVaultRedeemAndUnstakeParams(
            moneyBrinter,
            vaultShares,
            100, /* 1% slippage tolerance while burning vault shares*/
            amount0,
            amount1,
            100, /* 1% slippage tolerance while burning Lp tokens */
            zapper,
            zapper
        );
        uint256 amountOut = zapOutToToken1(alice, swapInfo, islandUnstakingParams, vaultParams, true, "");
        console.log("Token Out: ", amountOut);
        verifyMinOutputTokens(
            Wbera, islandUnstakingParams.amount0Min, islandUnstakingParams.amount1Min, swapInfo, noSwap, amountOut
        );
        verifyNoBalanceInZapper();
    }

    function test_successful_zap_out_yeet() public {
        // 1% slippage during LP redeem
        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(
            amount1,
            97842998386015666176, // assuming 2% slippage
            95886138418295352852, // assuming 2% slippage
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF802e79e01B6a43bc17680fb67fD8371977d264E047f47c67500Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff00692bB44820568223798f2577D092BAf0d696dd4701Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb801d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0193439A0E080805b5a147019410B3CeAf12bF4AE900Da547d8ce09e23E9e8053dd187B58841B5fB8D5d01277aaDBd9ea3dB8Fe9eA40eA6E09F6203724BdaE01ffff01EA2e981f185e6A4B53eb1B72792CF02e2EBCbDcB00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e030280150027882A7D759355842294A846F039c8e29EC0e3d501Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );
        IZapper.SingleTokenSwap memory noSwap;
        (IZapper.VaultRedeemParams memory vaultParams, IZapper.KodiakVaultUnstakingParams memory islandUnstakingParams)
        = prepareVaultRedeemAndUnstakeParams(moneyBrinter, vaultShares, 100, amount0, amount1, 100, zapper, zapper);
        uint256 amountOut = zapOutToToken0(alice, swapInfo, islandUnstakingParams, vaultParams, true, "");
        console.log("Token Out: ", amountOut);
        verifyMinOutputTokens(
            yeet, islandUnstakingParams.amount0Min, islandUnstakingParams.amount1Min, noSwap, swapInfo, amountOut
        );
        verifyNoBalanceInZapper();
    }

    function test_zap_out_honey_not_whitelisted() public {
        IZapper.SingleTokenSwap memory swap0 = prepareSwapInfo(
            amount0,
            32467901260885451504, // assuming 2% slippage
            31818543235667742473, // assuming 2% slippage
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e037bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD4102eaaa00f6451D031f084c96469A9887CCC520c960eaA34C01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d017507c1dc16935B82698e4C63f2746A2fCf994dF802eac90a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff00F1690B22082a467668F937B5D0d8024821eCee4800Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb80146eFC86F0D7455F135CC9df501673739d513E98201ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory swap1 = prepareSwapInfo(
            amount1,
            32388790745005735936, // assuming 2% slippage
            31741014930105621217, // assuming 2% slippage
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e037bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        (IZapper.VaultRedeemParams memory vaultParams, IZapper.KodiakVaultUnstakingParams memory islandUnstakingParams)
        = prepareVaultRedeemAndUnstakeParams(moneyBrinter, vaultShares, 100, amount0, amount1, 100, zapper, zapper);
        vm.prank(admin);
        contracts.zapper.updateSwappableTokens(honey, false);
        zapOut(
            true, "Zapper: output token not supported", alice, honey, swap0, swap1, islandUnstakingParams, vaultParams
        );
    }

    function test_successful_zap_out_honey() public {
        IZapper.SingleTokenSwap memory swap0 = prepareSwapInfo(
            amount0,
            32467901260885451504, // assuming 2% slippage
            31818543235667742473, // assuming 2% slippage
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e037bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD4102eaaa00f6451D031f084c96469A9887CCC520c960eaA34C01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d017507c1dc16935B82698e4C63f2746A2fCf994dF802eac90a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff00F1690B22082a467668F937B5D0d8024821eCee4800Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb80146eFC86F0D7455F135CC9df501673739d513E98201ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory swap1 = prepareSwapInfo(
            amount1,
            32388790745005735936, // assuming 2% slippage
            31741014930105621217, // assuming 2% slippage
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e037bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        (IZapper.VaultRedeemParams memory vaultParams, IZapper.KodiakVaultUnstakingParams memory islandUnstakingParams)
        = prepareVaultRedeemAndUnstakeParams(moneyBrinter, vaultShares, 100, amount0, amount1, 100, zapper, zapper);
        // whitelistHoneyToken
        vm.prank(admin);
        contracts.zapper.updateSwappableTokens(honey, true);
        uint256 initialBalanceHoney = IERC20(honey).balanceOf(alice);
        uint256 amountOut = zapOut(false, "", alice, honey, swap0, swap1, islandUnstakingParams, vaultParams);
        // check if final balance is greater by amountOut
        assertEq(
            IERC20(honey).balanceOf(alice) - initialBalanceHoney, amountOut, "ZapOutHoney: Honey not credited to user"
        );
        console.log("Token Out: ", amountOut);
        verifyMinOutputTokens(honey, 0, 0, swap0, swap1, amountOut);
        verifyNoBalanceInZapper();
    }

    function test_successful_zap_out_bera() public {
        // 1% slippage during LP redeem
        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(
            amount0,
            881023144322313440,
            863402681435867171,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD4102eaaa00f6451D031f084c96469A9887CCC520c960eaA34C01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory noSwap;
        (IZapper.VaultRedeemParams memory vaultParams, IZapper.KodiakVaultUnstakingParams memory islandUnstakingParams)
        = prepareVaultRedeemAndUnstakeParams(
            moneyBrinter,
            vaultShares,
            100, /* 1% slippage tolerance while burning vault shares*/
            amount0,
            amount1,
            100, /* 1% slippage tolerance while burning Lp tokens */
            zapper,
            zapper
        );
        uint256 initialBalanceBera = alice.balance;
        uint256 amountOut = zapOutNative(alice, swapInfo, noSwap, islandUnstakingParams, vaultParams, true, "");
        console.log("Token Out: ", amountOut);
        // verify native balnce increase
        assertEq(alice.balance - initialBalanceBera, amountOut, "ZapOutBera: Bera not credited to user");
        verifyNoBalanceInZapper();
    }
}
