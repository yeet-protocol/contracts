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

contract Zapper_Unit_Test_ZapInToken0 is ZapperForkTest {
    // ### Swap data for correct swap ###
    uint256 totalYeet;
    uint256 yeetBalance;
    uint256 toSwap;
    bytes pd;
    address executor;
    uint256 outputQuote;
    uint256 minOutput;
    IZapper.SingleTokenSwap correctSwap;

    function setUp() public {
        uint256 forkBlockNumber = 3382808;
        super.initContracts(forkBlockNumber);

        totalYeet = 200 ether;
        yeetBalance = 100 ether;
        toSwap = 100 ether;
        pd = vm.parseBytes(
            "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD410222e9000bb4CA6b807E785B594e27a4baA5c9d043835c1e01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff01B6a43bc17680fb67fD8371977d264E047f47c67501Da547d8ce09e23E9e8053dd187B58841B5fB8D5d011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE703559100f94D4cDFC1C0FFF801C93E4F7714c6d3d240308E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb87fd301ab8B3BF6c1F09f8B8955c1bd2C35d83e25d6bb1300Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01d23B295f4DA751eF920c6e6f6382A5C0ec51cFE401Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff0bAd1782b2a7020631249031618fB1Bd09CD926b31d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cDa547d8ce09e23E9e8053dd187B58841B5fB8D5d01d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
        );
        executor = 0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d;
        outputQuote = 987829420108900096;
        minOutput = 968072831706722094;
        correctSwap = IZapper.SingleTokenSwap({
            inputAmount: toSwap,
            outputQuote: outputQuote,
            outputMin: minOutput,
            executor: executor,
            path: pd
        });

        (correctStakingParams, correctMinShares) =
            prepareStakingParams(yeetBalance, minOutput, yeetBalance / 10, minOutput / 10);
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

    function test_zapIn_token1_not_whitelisted() public {
        vm.prank(admin);
        contracts.zapper.updateSwappableTokens(address(Wbera), false);
        fundAndApprove(Wbera, alice, 1000000 ether);
        zapInToken1(
            alice, correctSwap, correctStakingParams, correctVaultParams, false, "Zapper: input token not supported"
        );
        verifyNoBalanceInZapper();
    }

    function test_zapIn_not_enough_allowance() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        // reset approval to 0
        vm.prank(alice);
        IERC20(token0).approve(zapper, 0);
        bytes memory _error =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, zapper, 0, totalYeet);
        zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, false, string(_error));
        verifyNoBalanceInZapper();
    }

    function test_zapIn_not_enough_balance() public {
        uint256 amount = correctSwap.inputAmount + yeetBalance;
        address token0 = yeet;
        vm.prank(alice);
        IERC20(token0).approve(zapper, amount);
        uint256 aliceBalance = IERC20(token0).balanceOf(alice);
        vm.prank(alice);
        IERC20(token0).transfer(bob, aliceBalance);
        // expect openzeppelin error ERC20InsufficientBalance
        bytes memory _error = abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount);
        zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, false, string(_error));
        verifyNoBalanceInZapper();
    }

    function test_unsuccessful_swap() public {
        // This test would require mocking the swap router to simulate an unsuccessful swap
        // For simplicity, we'll just check if the swap fails due to insufficient output
        uint256 amount = 1 ether;
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);

        IZapper.SingleTokenSwap memory swapInfo = prepareSwapInfo(amount, amount, amount * 2, address(0), "");

        zapInToken0(alice, swapInfo, correctStakingParams, correctVaultParams, false, "");
        verifyNoBalanceInZapper();
    }

    // @note move to other file
    // ### Swap data for correct swap ###
    // no extra can be used when swapping in using token0
    // can only happen when zapping in using zapInToken1 and zapIn
    // token0 used in staking is more than the swap output
    // Zapper has enough extra balance to cover it but it should revert
    function test_overuse_token0_with_extra_balance() public {
        //wBera
        address token0 = yeet; // yeet
        fundAndApprove(token0, alice, totalYeet * 500);
        fundYeet(zapper, totalYeet * 500);
        // should revert because of arithmetic underflow
        bytes4 selector = bytes4(keccak256("addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)"));
        vm.mockCall(
            KodiakRouterStakingV1,
            abi.encodePacked(selector),
            abi.encode(correctStakingParams.amount0Max * 5, correctStakingParams.amount1Max * 5, 0, 0)
        );
        zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, false, "");
    }

    // token0 used in staking is more than the swap output
    // Zapper has enough extra balance to cover it but it should revert
    function test_overuse_token0_no_extra_balance() public {
        address token0 = yeet; // yeet
        fundAndApprove(token0, alice, totalYeet);
        bytes4 selector = bytes4(keccak256("addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)"));
        vm.mockCall(
            KodiakRouterStakingV1,
            abi.encodePacked(selector),
            abi.encode(correctStakingParams.amount1Max * 5, correctStakingParams.amount0Max * 5, 0)
        );
        zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, false, "");
        verifyNoBalanceInZapper();
        vm.clearMockedCalls();
    }

    function test_overuse_token1_with_extra_balance() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        fundWbera(zapper, outputQuote * 5);
        // token1 used should be more than the output of the swap
        // mock call to KodiakRouterStakingV1's 74dbc248 selector
        bytes4 selector = bytes4(keccak256("addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)"));
        vm.mockCall(
            KodiakRouterStakingV1,
            abi.encodePacked(selector),
            abi.encode(correctStakingParams.amount1Max * 5, correctStakingParams.amount0Max * 5, 0)
        );
        zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, false, "");
    }

    function test_overuse_token1_no_extra_balance() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(yeetBalance, outputQuote * 2, yeetBalance, outputQuote);
        IZapper.VaultDepositParams memory vaultParams = prepareVaultParams(minVaultShares, alice);
        zapInToken0(alice, correctSwap, correctStakingParams, vaultParams, false, "");
        verifyNoBalanceInZapper();
    }

    function test_lp_receiver_is_not_zapper() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);

        correctStakingParams.receiver = alice;
        // Need to make sure that deposit is not called on the vault
        // vaultShares should be 0
        uint256 vaultSharesInitial = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensInitial = IKodiakVaultV1(yeetIsland).balanceOf(alice);

        (uint256 islandTokensMinted, uint256 vaultSharesMinted) =
            zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, true, "");

        uint256 vaultSharesFinal = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensFinal = IKodiakVaultV1(yeetIsland).balanceOf(alice);

        assertGt(islandTokensMinted, 0);
        assertEq(vaultSharesMinted, 0);
        assertEq(vaultSharesFinal, vaultSharesInitial);
        assertEq(lpTokensFinal - lpTokensInitial, islandTokensMinted);
        verifyNoBalanceInZapper();
    }

    //
    function test_lp_receiver_is_zapper() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        correctVaultParams.receiver = zapper;
        uint256 vaultSharesInitial = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensInitial = IKodiakVaultV1(yeetIsland).balanceOf(alice);
        (uint256 islandTokensMinted, uint256 vaultSharesMinted) =
            zapInToken0(alice, correctSwap, correctStakingParams, correctVaultParams, true, "");
        uint256 vaultSharesFinal = IERC20(correctVaultParams.vault).totalSupply();
        uint256 lpTokensFinal = IKodiakVaultV1(yeetIsland).balanceOf(alice);
        assertGt(islandTokensMinted, 0);
        assertGt(vaultSharesMinted, 0);
        assertEq(vaultSharesFinal, vaultSharesInitial + vaultSharesMinted);
        assertEq(lpTokensFinal, lpTokensInitial);
        verifyNoBalanceInZapper();
    }

    function test_Compounding_vault_shares_minted_not_enough() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        console.log("minShares: ", correctVaultParams.minShares);
        correctVaultParams.minShares *= 200;
        console.log("minShares: ", correctVaultParams.minShares);
        zapInToken0(
            alice, correctSwap, correctStakingParams, correctVaultParams, false, "Zapper: insufficient shares minted"
        );
        verifyNoBalanceInZapper();
    }
    // shares get minted to the msg.sender

    function test_vault_shares_minted_to_zapper() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        correctVaultParams.receiver = zapper;
        uint256 initialSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        fundAndApprove(token0, bob, totalYeet);
        vm.prank(bob);
        (uint256 islandTokensMinted, uint256 vaultShares) =
            contracts.zapper.zapInToken0(correctSwap, correctStakingParams, correctVaultParams);
        uint256 finalSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        assertGt(islandTokensMinted, 0);
        assertGt(vaultShares, 0);
        assertEq(finalSharesBob, initialSharesBob + vaultShares);
        verifyNoBalanceInZapper();
    }

    // shares get minted to mentioned receiver
    function test_vault_shares_minted_to_receiver() public {
        address token0 = yeet;
        fundAndApprove(token0, alice, totalYeet);
        correctVaultParams.receiver = alice;
        uint256 initialSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        uint256 initialSharesAlice = IERC20(moneyBrinter).balanceOf(alice);
        fundAndApprove(token0, bob, totalYeet);
        vm.prank(bob);
        (uint256 islandTokensMinted, uint256 vaultShares) =
            contracts.zapper.zapInToken0(correctSwap, correctStakingParams, correctVaultParams);
        uint256 finalSharesBob = IERC20(moneyBrinter).balanceOf(bob);
        uint256 finalSharesAlice = IERC20(moneyBrinter).balanceOf(alice);
        assertGt(islandTokensMinted, 0);
        assertGt(vaultShares, 0);
        assertEq(finalSharesBob, initialSharesBob);
        assertEq(finalSharesAlice, initialSharesAlice + vaultShares);
        verifyNoBalanceInZapper();
    }
}
