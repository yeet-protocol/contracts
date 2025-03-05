// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {ForkTest} from "../ForkTest.sol";
import {IZapper} from "../../src/interfaces/IZapper.sol";
import {IOBRouter} from "../../src/interfaces/oogabooga/IOBRouter.sol";
import {ZapperForkTest} from "./ZapperForkTest.sol";

contract ZapIn_Integration_Test is ZapperForkTest {
    function setUp() public {
        uint256 forkBlockNumber = 3382808;
        super.initContracts(forkBlockNumber);
    }

    function test_successful_zap_in_wBera() public {
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

        // find min shares
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);
        // approve Wbera to zapper
        fundAndApprove(Wbera, alice, totalWbera);
        (uint256 _islandTokensMinted, uint256 _vaultShares) =
            zapInToken1(alice, swapInfo, stakingParams, vaultParams, true, "");
        console.log("Island Tokens Minted: ", _islandTokensMinted);
        console.log("Vault Shares: ", _vaultShares);
    }

    function test_successful_zap_in_yeet() public {
        uint256 totalYeet = 200 ether;
        uint256 toSwap = 100 ether;

        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(
            toSwap,
            987829420108900096,
            968072831706722094,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD410222e9000bb4CA6b807E785B594e27a4baA5c9d043835c1e01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff01B6a43bc17680fb67fD8371977d264E047f47c67501Da547d8ce09e23E9e8053dd187B58841B5fB8D5d011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE703559100f94D4cDFC1C0FFF801C93E4F7714c6d3d240308E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb87fd301ab8B3BF6c1F09f8B8955c1bd2C35d83e25d6bb1300Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01d23B295f4DA751eF920c6e6f6382A5C0ec51cFE401Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff0bAd1782b2a7020631249031618fB1Bd09CD926b31d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cDa547d8ce09e23E9e8053dd187B58841B5fB8D5d01d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );

        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(100e18, swapInfo.outputMin, 90e18, swapInfo.outputMin / 10);
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);

        fundAndApprove(yeet, alice, totalYeet);
        (uint256 _islandTokensMinted, uint256 _vaultShares) =
            zapInToken0(alice, swapInfo, stakingParams, vaultParams, true, "");

        console.log("Island Tokens Minted: ", _islandTokensMinted);
        console.log("Vault Shares: ", _vaultShares);
        assertEq(IERC20(yeet).balanceOf(zapper), 0);
        assertEq(IERC20(Wbera).balanceOf(zapper), 0);
    }

    function test_successful_zap_in_honey() public {
        uint256 totalHoney = 200 ether;
        uint256 toSwap = 100 ether;
        address executor = 0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d;

        IZapper.SingleTokenSwap memory s1 = prepareSwapInfo(
            toSwap,
            2771411591840386927,
            2715983360003579188,
            executor,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff0bAd1782b2a7020631249031618fB1Bd09CD926b31d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cDa547d8ce09e23E9e8053dd187B58841B5fB8D5d01d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory s0 = prepareSwapInfo(
            toSwap,
            279158679197688000062,
            273575505613734240060,
            executor,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0302bfff0bAd1782b2a7020631249031618fB1Bd09CD926b31d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cDa547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb801d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff01B6a43bc17680fb67fD8371977d264E047f47c67500Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );

        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(273575505613734240060, 2715983360003579188, 271575505613734240060, 2615983360003579188);
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);

        (uint256 _islandTokensMinted, uint256 _vaultShares) =
            zapIn(alice, honey, totalHoney, s0, s1, stakingParams, vaultParams, true, "");

        console.log("Island Tokens Minted: ", _islandTokensMinted);
        console.log("Vault Shares: ", _vaultShares);
        assertEq(IERC20(yeet).balanceOf(zapper), 0);
        assertEq(IERC20(Wbera).balanceOf(zapper), 0);
        assertEq(IERC20(honey).balanceOf(zapper), 0);
    }

    function test_successful_zap_in_native() public {
        uint256 totalBera = 2 ether;
        uint256 toSwap = 1 ether;
        IZapper.SingleTokenSwap memory swap0 = prepareSwapInfo(
            toSwap,
            100761302310950207488,
            98746076264731203338,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );
        IZapper.SingleTokenSwap memory swap1;
        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(swap0.outputMin, 1e18, swap0.outputMin / 10, 1e17);
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);

        (uint256 _islandTokensMinted, uint256 _vaultShares) =
            zapInNative(alice, totalBera * 2, swap0, swap1, stakingParams, vaultParams, true, "");

        console.log("Island Tokens Minted: ", _islandTokensMinted);
        console.log("Vault Shares: ", _vaultShares);

        // find wbera and yeet balance of user and log
        console.log("Returned Wbera balance: ", IERC20(Wbera).balanceOf(alice)); // 19641471582948255 almost 0.2
        console.log("Returned Yeet balance: ", IERC20(yeet).balanceOf(alice)); // 1945700254427524889 -> 1.95
        console.log("Zapper's Yeet balance: ", IERC20(yeet).balanceOf(zapper));
        console.log("Zapper's Wbera balance: ", IERC20(Wbera).balanceOf(zapper));
    }
}

// Honey
// Wbera
// Bera
// Yeet

// Yeet to Bera
// Honey to yeet
// Honey to WBera
