// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import "forge-std/StdUtils.sol";
import {ForkTest} from "../ForkTest.sol";
import {IKodiakVaultV1} from "interfaces/kodiak/IKodiakVaultV1.sol";
import {IZapper} from "interfaces/IZapper.sol";
import {IOBRouter} from "interfaces/oogabooga/IOBRouter.sol";
import {ZapperForkTest} from "./ZapperForkTest.sol";
import {Zapper} from "contracts/Zapper.sol";

contract Zapper_Unit_Test_ZapInToken1 is ZapperForkTest {
    // ### Swap data for correct swap ###
    uint256 totalYeet;
    uint256 toSwap;
    bytes pd;
    address executor;
    uint256 outputQuote;
    uint256 minOutput;
    uint256 remainingWbera;
    IZapper.SingleTokenSwap correctSwap;

    function setUp() public {
        uint256 forkBlockNumber = 3382808;
        super.initContracts(forkBlockNumber);

        uint256 totalWbera = 2 ether;
        uint256 wBeraToSwap = 1 ether;
        remainingWbera = 1 ether;
        executor = 0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d;
        outputQuote = 100761302310950207488;
        minOutput = 98746076264731203338;
        correctSwap = prepareSwapInfo(
            wBeraToSwap,
            outputQuote,
            minOutput,
            executor,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0000E4aaF1351de4c0264C5c7056Ef3777b41BD8e03Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );

        (correctStakingParams, correctMinShares) =
            prepareStakingParams(correctSwap.outputMin, totalWbera - wBeraToSwap, correctSwap.outputMin / 10, 1e17);
        correctVaultParams = prepareVaultParams(correctMinShares, alice);
    }

    // correct staking params
    IZapper.KodiakVaultStakingParams correctStakingParams;
    IZapper.VaultDepositParams correctVaultParams;
    uint256 correctMinShares;

    function test_zapIn_token0_not_whitelisted() public {
        vm.prank(admin);
        contracts.zapper.updateSwappableTokens(yeet, false);
        fundAndApprove(yeet, alice, 1000000 ether);
        zapInToken0(
            alice, correctSwap, correctStakingParams, correctVaultParams, false, "Zapper: input token not supported"
        );
        verifyNoBalanceInZapper();
    }

    function test_zapIn_not_enough_balance() public {
        uint256 amount = correctSwap.inputAmount + remainingWbera;
        address token1 = Wbera;
        vm.prank(alice);
        IERC20(token1).approve(zapper, amount);
        uint256 aliceBalance = IERC20(token1).balanceOf(alice);
        vm.prank(alice);
        IERC20(token1).transfer(bob, aliceBalance);
        // expect openzeppelin error ERC20InsufficientBalance
        // bytes memory _error = abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount);
        zapInToken1(alice, correctSwap, correctStakingParams, correctVaultParams, false, "");
        verifyNoBalanceInZapper();
    }

    function test_unsuccessful_swap() public {
        // This test would require mocking the swap router to simulate an unsuccessful swap
        // For simplicity, we'll just check if the swap fails due to insufficient output
        uint256 amount = 1 ether;
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);

        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(amount, amount, amount * 2, address(0), "");

        zapInToken1(alice, swapInfo, correctStakingParams, correctVaultParams, false, "");
        verifyNoBalanceInZapper();
    }

    function test_lp_receiver_is_not_zapper() public {
        address token1 = Wbera;
        uint256 totalWbera = correctSwap.inputAmount + correctStakingParams.amount1Max;
        fundAndApprove(token1, alice, totalWbera);
        correctStakingParams.receiver = alice;
        // Need to make sure that deposit is not called on the vault
        // vaultShares should be 0
        uint256 vaultSharesInitial = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensInitial = IKodiakVaultV1(yeetIsland).balanceOf(alice);

        (uint256 islandTokensMinted, uint256 vaultSharesMinted) =
            zapInToken1(alice, correctSwap, correctStakingParams, correctVaultParams, true, "");

        uint256 vaultSharesFinal = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensFinal = IKodiakVaultV1(yeetIsland).balanceOf(alice);

        assertGt(islandTokensMinted, 0);
        assertEq(vaultSharesMinted, 0);
        assertEq(vaultSharesFinal, vaultSharesInitial);
        assertEq(lpTokensFinal - lpTokensInitial, islandTokensMinted);
        verifyNoBalanceInZapper();
    }

    function test_vault_shares_minted_to_msg_sender() public {
        correctVaultParams.receiver = zapper;
        address token1 = Wbera;
        uint256 totalWbera = correctSwap.inputAmount + correctStakingParams.amount1Max;
        fundAndApprove(token1, bob, totalWbera);
        uint256 initialSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        fundAndApprove(token1, bob, totalWbera);
        vm.prank(bob);
        (uint256 islandTokensMinted, uint256 vaultShares) =
            contracts.zapper.zapInToken1(correctSwap, correctStakingParams, correctVaultParams);
        uint256 finalSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        assertGt(islandTokensMinted, 0);
        assertGt(vaultShares, 0);
        assertEq(finalSharesBob, initialSharesBob + vaultShares);
        verifyNoBalanceInZapper();
    }
}
