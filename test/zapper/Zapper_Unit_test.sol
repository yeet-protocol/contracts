// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ZapperMock} from "test/mocks/ZapperMock.sol";
import {ZapperForkTest} from "./ZapperForkTest.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IZapper} from "interfaces/IZapper.sol";
import {IOBRouter} from "interfaces/oogabooga/IOBRouter.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IKodiakV1RouterStaking} from "interfaces/kodiak/IKodiakV1RouterStaking.sol";
import {IKodiakVaultV1} from "interfaces/kodiak/IKodiakVaultV1.sol";
import {console} from "forge-std/console.sol";

contract Zapper_Unit_Test is ZapperForkTest {
    using SafeERC20 for IERC20;

    ZapperMock zapperMock;
    address mockZapperAddress;

    uint256 swapAmount = 100 ether;
    bytes pd = vm.parseBytes(
        "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401011740F679325ef3686B2f574e392007A92e4BeD410222e9000bb4CA6b807E785B594e27a4baA5c9d043835c1e01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff01B6a43bc17680fb67fD8371977d264E047f47c67501Da547d8ce09e23E9e8053dd187B58841B5fB8D5d011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE703559100f94D4cDFC1C0FFF801C93E4F7714c6d3d240308E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb87fd301ab8B3BF6c1F09f8B8955c1bd2C35d83e25d6bb1300Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01d23B295f4DA751eF920c6e6f6382A5C0ec51cFE401Da547d8ce09e23E9e8053dd187B58841B5fB8D5d010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff0bAd1782b2a7020631249031618fB1Bd09CD926b31d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cDa547d8ce09e23E9e8053dd187B58841B5fB8D5d01d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
    );
    address executor = 0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d;
    uint256 outputQuote = 987829420108900096;
    uint256 minOutput = 968072831706722094;

    function setUp() public {
        uint256 forkBlockNumber = 3382808;
        super.initContracts(forkBlockNumber);
        zapperMock = new ZapperMock(obRouter, KodiakRouterStakingV1);
        zapperMock.setCompoundingVault(address(moneyBrinter), true);
        zapperMock.updateWhitelistedKodiakVault(address(yeetIsland), true);
        mockZapperAddress = address(zapperMock);
    }

    // function test_yeetIn_approveAndAddLiquidityToKodiakVault() public {
    //     // Setup
    //     uint256 token0Amount = 1000e18;
    //     uint256 token1Amount = 1000e18;
    //     fundYeet(bob, token0Amount);
    //     fundWbera(bob, token1Amount);
    //     IERC20(yeet).approve(mockZapperAddress, token0Amount);
    //     IERC20(Wbera).approve(mockZapperAddress, token1Amount);

    //     IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
    //         kodiakVault: address(yeetIsland),
    //         amount0Max: token0Amount,
    //         amount1Max: token1Amount,
    //         amount0Min: 0,
    //         amount1Min: 0,
    //         amountSharesMin: 0
    //     });

    //     IZapper.VaultDepositParams memory vaultParams = IZapper.VaultDepositParams({
    //         vault: address(moneyBrinter),
    //         receiver: address(this),
    //         amountSharesMin: 0
    //     });

    //     // Test
    //     (uint256 islandTokensReceived, uint256 vaultSharesReceived) = zapperMock.publicYeetIn(
    //         IERC20(yeet),
    //         IERC20(Wbera),
    //         token0Amount,
    //         token1Amount,
    //         stakingParams,
    //         vaultParams
    //     );

    //     // Assert
    //     assertGt(islandTokensReceived, 0, "Should receive island tokens");
    //     assertGt(vaultSharesReceived, 0, "Should receive vault shares");
    // }

    // function test_yeetIn_insufficientTokens() public {
    //     // Setup
    //     uint256 token0Amount = 1000e18;
    //     uint256 token1Amount = 1000e18;
    //     fundYeet(bob, token0Amount);
    //     fundWbera(bob, token1Amount);
    //     IERC20(yeet).approve(mockZapperAddress, token0Amount);
    //     IERC20(Wbera).approve(mockZapperAddress, token1Amount);

    //     IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
    //         kodiakVault: address(yeetIsland),
    //         amount0Max: token0Amount + 1, // More than available
    //         amount1Max: token1Amount,
    //         amount0Min: 0,
    //         amount1Min: 0,
    //         amountSharesMin: 0
    //     });

    //     IZapper.VaultDepositParams memory vaultParams = IZapper.VaultDepositParams({
    //         vault: address(moneyBrinter),
    //         receiver: address(this),
    //         amountSharesMin: 0
    //     });

    //     // Test & Assert
    //     vm.expectRevert(); // Expect arithmetic underflow
    //     zapperMock.publicYeetIn(
    //         IERC20(yeet),
    //         IERC20(Wbera),
    //         token0Amount + 1,
    //         token1Amount,
    //         stakingParams,
    //         vaultParams
    //     );
    // }

    function test_verifyTokenAndSwap_notWhitelisted() public {
        // Setup
        address nonWhitelistedToken = address(0x123);
        IZapper.SingleTokenSwap memory correctSwap = IZapper.SingleTokenSwap({
            inputAmount: swapAmount,
            outputQuote: outputQuote,
            outputMin: minOutput,
            executor: executor,
            path: pd
        });

        // Test & Assert
        vm.expectRevert("Zapper: input token not supported");
        zapperMock.publicVerifyTokenAndSwap(correctSwap, nonWhitelistedToken, address(yeet), address(this));
    }

    // No calls should be made to the OB Router if input amount is zero
    function test_verifyTokenAndSwap_zero_amountIn() public {
        // Setup
        IZapper.SingleTokenSwap memory correctSwap = IZapper.SingleTokenSwap({
            inputAmount: 0,
            outputQuote: outputQuote,
            outputMin: minOutput,
            executor: executor,
            path: pd
        });

        // Test & Assert
        vm.expectCall(address(obRouter), abi.encodeWithSelector(IOBRouter.swap.selector), 0);
        uint256 amountOut =
            zapperMock.publicVerifyTokenAndSwap(correctSwap, address(Wbera), address(yeet), address(this));
        assertEq(amountOut, 0);
    }

    function test_approveRouterAndSwap_insufficientBalance() public {
        // approve to router
        IERC20(yeet).approve(mockZapperAddress, swapAmount);

        IOBRouter.swapTokenInfo memory swapTokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(yeet),
            outputToken: address(Wbera),
            inputAmount: swapAmount,
            outputQuote: outputQuote,
            outputMin: minOutput,
            outputReceiver: zapper // fork test zapper address as the path data belongs to that address as receiver
        });

        bytes memory _error =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, mockZapperAddress, 0, swapAmount);
        // Test & Assert
        vm.expectRevert(_error); // Expect revert due to insufficient balance
        vm.prank(alice);
        zapperMock.publicApproveRouterAndSwap(swapTokenInfo, pd, executor);
    }

    function test_approveRouterAndSwap_sufficientBalance() public {
        // Setup
        fundYeet(bob, swapAmount);
        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, swapAmount);
        IOBRouter.swapTokenInfo memory swapTokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(yeet),
            outputToken: address(Wbera),
            inputAmount: swapAmount,
            outputQuote: outputQuote,
            outputMin: minOutput,
            outputReceiver: zapper // fork test zapper address as the path data belongs to that address as receiver
        });
        uint256 initialWberaBalance = IERC20(Wbera).balanceOf(zapper);
        vm.prank(bob);
        // Test
        uint256 amountOut = zapperMock.publicApproveRouterAndSwap(swapTokenInfo, pd, executor);
        uint256 finalWberaBalance = IERC20(Wbera).balanceOf(zapper);
        // Assert
        assertGe(amountOut, minOutput, "Should receive tokens from swap");
        assertEq(
            finalWberaBalance, initialWberaBalance + amountOut, "Receiver should receive the wbera swap out amount"
        );
    }

    function test_approveRouterAndSwap_sufficientBalance_incorrectExecutor() public {
        // Setup
        fundYeet(bob, swapAmount);
        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, swapAmount);
        IOBRouter.swapTokenInfo memory swapTokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(yeet),
            outputToken: address(Wbera),
            inputAmount: swapAmount,
            outputQuote: outputQuote,
            outputMin: minOutput,
            outputReceiver: zapper // fork test zapper address as the path data belongs to that address as receiver
        });
        vm.prank(bob);
        // Test
        vm.expectRevert();
        zapperMock.publicApproveRouterAndSwap(swapTokenInfo, pd, alice);
    }

    function test_approveRouterAndSwap_sufficientBalance_incorrectPathData() public {
        // Setup
        fundYeet(bob, swapAmount);
        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, swapAmount);
        IOBRouter.swapTokenInfo memory swapTokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(yeet),
            outputToken: address(Wbera),
            inputAmount: swapAmount,
            outputQuote: outputQuote,
            outputMin: minOutput,
            outputReceiver: zapper // fork test zapper address as the path data belongs to that address as receiver
        });
        vm.prank(bob);
        // Test
        vm.expectRevert();
        zapperMock.publicApproveRouterAndSwap(swapTokenInfo, bytes(""), executor);
    }

    function test_approveAndAddLiquidityToKodiakVault_vault_not_whitelisted() public {
        fundYeet(bob, 1000 ether);
        fundWbera(bob, 1000 ether);
        vm.prank(bob);
        IERC20(yeet).approve(mockZapperAddress, 1000 ether);
        vm.prank(bob);
        IERC20(Wbera).approve(mockZapperAddress, 1000 ether);
        address nonWhitelistedVault = address(0x123);
        console.log("nonWhitelistedVault", nonWhitelistedVault);
        IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
            kodiakVault: nonWhitelistedVault,
            amount0Max: 1000 ether,
            amount1Max: 1000 ether,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            receiver: mockZapperAddress
        });

        // Test & Assert
        vm.expectRevert();
        vm.prank(bob);
        zapperMock.publicApproveAndAddLiquidityToKodiakVault(
            nonWhitelistedVault, IERC20(yeet), IERC20(Wbera), stakingParams
        );
    }

    function test_approveAndAddLiquidityToKodiakVault_tokens_not_acquired() public {
        // Setup
        uint256 token0Amount = 1000e18;
        uint256 token1Amount = 1000e18;
        fundYeet(bob, token0Amount);
        fundWbera(bob, token1Amount);

        // get amount of shares that should be minted
        (uint256 amount0, uint256 amount1, uint256 mintAmount) =
            IKodiakVaultV1(yeetIsland).getMintAmounts(token0Amount, token1Amount);

        IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
            kodiakVault: address(yeetIsland),
            amount0Max: token0Amount,
            amount1Max: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: mintAmount,
            receiver: mockZapperAddress
        });

        bytes memory _error =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, mockZapperAddress, 0, token0Amount);

        // Test & Assert
        vm.expectRevert(_error);
        vm.prank(bob);
        zapperMock.publicApproveAndAddLiquidityToKodiakVault(
            address(yeetIsland), IERC20(yeet), IERC20(Wbera), stakingParams
        );
    }

    function test_approveAndAddLiquidityToKodiakVault_tokens_acquired_insufficientSharesMinted() public {
        // Setup
        uint256 token0Amount = 1000e18;
        uint256 token1Amount = 1000e18;
        fundYeet(bob, token0Amount);
        fundWbera(bob, token1Amount);

        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, token0Amount);
        vm.prank(bob);
        IERC20(Wbera).safeTransfer(mockZapperAddress, token1Amount);

        // get amount of shares that should be minted
        (uint256 amount0, uint256 amount1, uint256 mintAmount) =
            IKodiakVaultV1(yeetIsland).getMintAmounts(token0Amount, token1Amount);

        IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
            kodiakVault: address(yeetIsland),
            amount0Max: token0Amount,
            amount1Max: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: mintAmount + 1, // Set to an impossibly high value
            receiver: mockZapperAddress
        });

        // Test & Assert
        vm.expectRevert("below min amounts");
        vm.prank(bob);
        zapperMock.publicApproveAndAddLiquidityToKodiakVault(
            address(yeetIsland), IERC20(yeet), IERC20(Wbera), stakingParams
        );
    }

    function test_approveAndAddLiquidityToKodiakVault_success_receiver_is_zapper() public {
        // Setup
        uint256 token0Amount = 1000e18;
        uint256 token1Amount = 1000e18;
        fundYeet(bob, token0Amount);
        fundWbera(bob, token1Amount);
        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, token0Amount);
        vm.prank(bob);
        IERC20(Wbera).safeTransfer(mockZapperAddress, token1Amount);

        // get amount of shares that should be minted
        (uint256 amount0, uint256 amount1, uint256 mintAmount) =
            IKodiakVaultV1(yeetIsland).getMintAmounts(token0Amount, token1Amount);

        IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
            kodiakVault: address(yeetIsland),
            amount0Max: token0Amount,
            amount1Max: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            receiver: mockZapperAddress
        });

        vm.prank(bob);
        (uint256 amount0Used, uint256 amount1Used, uint256 finalMintAmount) = zapperMock
            .publicApproveAndAddLiquidityToKodiakVault(address(yeetIsland), IERC20(yeet), IERC20(Wbera), stakingParams);

        uint256 finalZapperBalance = IERC20(yeetIsland).balanceOf(mockZapperAddress);
        uint256 finalBobBalance = IERC20(yeetIsland).balanceOf(bob);

        // Assert
        assertGt(amount0Used, 0, "Should use some amount of yeet");
        assertGt(amount1Used, 0, "Should use some amount of Wbera");
        assertGt(finalMintAmount, 0, "Should mint some amount of shares");
        assertEq(amount0Used, amount0, "Should use same amount of yeet");
        assertEq(amount1Used, amount1, "Should use same amount of Wbera");
        assertEq(finalMintAmount, mintAmount, "Should mint same amount of shares");
        assertEq(finalBobBalance, 0, "Bob should not receive any minted islandTokens");
        assertEq(finalZapperBalance, mintAmount, "Zapper should receive all minted islandTokens");
    }

    function test_approveAndAddLiquidityToKodiakVault_success_receiver_is_not_zapper() public {
        // Setup
        uint256 token0Amount = 1000e18;
        uint256 token1Amount = 1000e18;
        fundYeet(bob, token0Amount);
        fundWbera(bob, token1Amount);
        vm.prank(bob);
        IERC20(yeet).safeTransfer(mockZapperAddress, token0Amount);
        vm.prank(bob);
        IERC20(Wbera).safeTransfer(mockZapperAddress, token1Amount);

        // get amount of shares that should be minted
        (uint256 amount0, uint256 amount1, uint256 mintAmount) =
            IKodiakVaultV1(yeetIsland).getMintAmounts(token0Amount, token1Amount);

        IZapper.KodiakVaultStakingParams memory stakingParams = IZapper.KodiakVaultStakingParams({
            kodiakVault: address(yeetIsland),
            amount0Max: token0Amount,
            amount1Max: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            receiver: alice
        });

        vm.prank(bob);
        (uint256 amount0Used, uint256 amount1Used, uint256 finalMintAmount) = zapperMock
            .publicApproveAndAddLiquidityToKodiakVault(address(yeetIsland), IERC20(yeet), IERC20(Wbera), stakingParams);

        uint256 finalZapperBalance = IERC20(yeetIsland).balanceOf(mockZapperAddress);
        uint256 finalAliceBalance = IERC20(yeetIsland).balanceOf(alice);

        // Assert
        assertGt(amount0Used, 0, "Should use some amount of yeet");
        assertGt(amount1Used, 0, "Should use some amount of Wbera");
        assertGt(finalMintAmount, 0, "Should mint some amount of shares");
        assertEq(amount0Used, amount0, "Should use same amount of yeet");
        assertEq(amount1Used, amount1, "Should use same amount of Wbera");
        assertEq(finalMintAmount, mintAmount, "Should mint same amount of shares");
        assertEq(finalZapperBalance, 0, "Zapper should not receive any minted islandTokens");
        assertEq(finalAliceBalance, mintAmount, "Alice should receive all minted islandTokens");
    }

    function test_depositIntoVault_zeroAddress_receiver() public {
        // Setup
        IZapper.VaultDepositParams memory vaultParams =
            IZapper.VaultDepositParams({vault: moneyBrinter, receiver: address(0), minShares: 0});

        // Test & Assert
        vm.expectRevert("Zapper: zero address beneficiary");
        vm.prank(bob);
        zapperMock.publicDepositIntoVault(vaultParams, 1000e18);
    }

    function test_depositIntoVault_notWhitelisted() public {
        // Setup
        address nonWhitelistedVault = address(0x123);
        IZapper.VaultDepositParams memory vaultParams =
            IZapper.VaultDepositParams({vault: nonWhitelistedVault, receiver: address(this), minShares: 0});

        // Test & Assert
        vm.expectRevert("Zapper: vault not whitelisted");
        vm.prank(bob);
        zapperMock.publicDepositIntoVault(vaultParams, 1000e18);
    }

    function test_depositIntoVault_insufficientShares() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, depositAmount);
        //preview deposit
        uint256 shares = IERC4626(address(moneyBrinter)).previewDeposit(depositAmount);
        // Setup
        IZapper.VaultDepositParams memory vaultParams = IZapper.VaultDepositParams({
            vault: address(moneyBrinter),
            receiver: address(this),
            minShares: shares + 1 // Set to an impossibly high value
        });

        // Test & Assert
        vm.expectRevert("Zapper: insufficient shares minted");
        vm.prank(bob);
        zapperMock.publicDepositIntoVault(vaultParams, 1000e18);
    }

    function test_depositIntoVault_success_receiver_not_zapper() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, depositAmount);

        //preview deposit
        uint256 shares = IERC4626(address(moneyBrinter)).previewDeposit(depositAmount);

        IZapper.VaultDepositParams memory vaultParams =
            IZapper.VaultDepositParams({vault: address(moneyBrinter), receiver: bob, minShares: shares});

        // Test
        vm.prank(bob);
        uint256 sharesReceived = zapperMock.publicDepositIntoVault(vaultParams, depositAmount);

        uint256 finalBalance = IERC20(moneyBrinter).balanceOf(bob);
        uint256 finalZapperBalance = IERC20(moneyBrinter).balanceOf(mockZapperAddress);

        // Assert
        assertEq(sharesReceived, shares, "Should receive same amount of shares");
        assertEq(finalBalance, shares, "Bob(receiver) Should receive same amount of shares");
        assertEq(finalZapperBalance, 0, "Zapper should not receive any shares");
    }

    function test_depositIntoVault_success_receiver_is_zapper() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, depositAmount);

        //preview deposit
        uint256 shares = IERC4626(address(moneyBrinter)).previewDeposit(depositAmount);

        IZapper.VaultDepositParams memory vaultParams =
            IZapper.VaultDepositParams({vault: address(moneyBrinter), receiver: mockZapperAddress, minShares: shares});

        vm.prank(alice);
        // Test
        uint256 sharesReceived = zapperMock.publicDepositIntoVault(vaultParams, depositAmount);

        uint256 finalBalanceMsgSender = IERC20(moneyBrinter).balanceOf(alice);
        uint256 finalZapperBalance = IERC20(moneyBrinter).balanceOf(mockZapperAddress);
        // Assert
        assertEq(sharesReceived, shares, "Should receive same amount of shares");
        assertEq(finalBalanceMsgSender, shares, "Alice(_msgSender()) Should receive same amount of shares");
        assertEq(finalZapperBalance, 0, "Zapper should not receive any shares");
    }

    function test_clearUserDebt_success() public {
        // Setup
        uint256 token0Debt = 100e18;
        uint256 token1Debt = 200e18;
        fundYeet(mockZapperAddress, token0Debt);
        fundWbera(mockZapperAddress, token1Debt);

        // Test
        zapperMock.publicClearUserDebt(IERC20(yeet), IERC20(Wbera), token0Debt, token1Debt, bob);

        // Assert
        assertEq(IERC20(yeet).balanceOf(bob), token0Debt, "Bob Should receive yeet debt");
        assertEq(IERC20(Wbera).balanceOf(bob), token1Debt, "Bob Should receive Wbera debt");
    }

    function test_yeetOut_withdraws_from_vault() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: mockZapperAddress,
            minAssets: 0
        });

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: mockZapperAddress
        });

        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) =
            zapperMock.publicYeetOut(redeemParams, unstakeParams);

        // Assert
        assertGt(token0Debt, 0, "Should have received token0");
        assertGt(token1Debt, 0, "Should have received token1");
        assertEq(IERC20(moneyBrinter).balanceOf(bob), 0, "All shares should be burned");
    }

    function test_yeetOut_islandTokens_sent_to_other_address() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);
        // preview redeem
        uint256 islandTokensReceived = IERC4626(address(moneyBrinter)).previewRedeem(initialShares);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: alice, // Set receiver to a different address
            minAssets: 0
        });

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice
        });

        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // Test
        // assert no calls(0) are made to the island contract(kodiak vault)
        vm.expectCall(address(yeetIsland), abi.encodeWithSelector(IKodiakV1RouterStaking.removeLiquidity.selector), 0);
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) =
            zapperMock.publicYeetOut(redeemParams, unstakeParams);

        // Assert
        assertEq(token0Debt, 0, "Should not have received token0");
        assertEq(token1Debt, 0, "Should not have received token1");
        assertEq(IERC20(yeetIsland).balanceOf(alice), islandTokensReceived, "Alice should have received island tokens");
    }

    function test_yeetOut_islandTokens_received_by_zapper() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: mockZapperAddress,
            minAssets: 0
        });

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: mockZapperAddress
        });

        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) =
            zapperMock.publicYeetOut(redeemParams, unstakeParams);

        // Assert
        assertGt(token0Debt, 0, "Should have received token0");
        assertGt(token1Debt, 0, "Should have received token1");
        assertEq(IERC20(yeetIsland).balanceOf(mockZapperAddress), 0, "Zapper should have unstaked all island tokens");
    }

    function test_yeetOut_tokens_received_by_other_address() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: mockZapperAddress,
            minAssets: 0
        });

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice // Set receiver to a different address
        });

        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) =
            zapperMock.publicYeetOut(redeemParams, unstakeParams);

        // Assert
        assertEq(token0Debt, 0, "Should not have received token0");
        assertEq(token1Debt, 0, "Should not have received token1");
        assertGt(IERC20(yeet).balanceOf(alice), 0, "Alice should have received token0");
        assertGt(IERC20(Wbera).balanceOf(alice), 0, "Alice should have received token1");
    }

    function test_withdrawFromVault_notWhitelisted() public {
        // Setup
        address nonWhitelistedVault = address(0x123);
        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: nonWhitelistedVault,
            shares: 1000e18,
            receiver: mockZapperAddress,
            minAssets: 0
        });

        // Test & Assert
        vm.expectRevert("Zapper: vault not whitelisted");
        zapperMock.publicWithdrawFromVault(redeemParams);
    }

    function test_withdrawFromVault_not_enough_approval() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: address(this),
            minAssets: 0
        });

        bytes memory errorString = abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientAllowance.selector, mockZapperAddress, 0, redeemParams.shares
        );

        vm.expectRevert(errorString);
        vm.prank(bob);
        // Test
        uint256 amountWithdrawn = zapperMock.publicWithdrawFromVault(redeemParams);
    }

    function test_withdrawFromVault_not_enough_balance() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares + 1,
            receiver: address(this),
            minAssets: 0
        });

        // approve more than the balance
        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares + 1);

        bytes memory errorString = abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector, bob, initialShares, initialShares + 1
        );

        vm.expectRevert(errorString);
        vm.prank(bob);
        // Test
        uint256 amountWithdrawn = zapperMock.publicWithdrawFromVault(redeemParams);
    }

    function test_withdrawFromVault_slippage_exceeded() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);
        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // preview redeem
        uint256 islandTokensReceived = IERC4626(address(moneyBrinter)).previewRedeem(initialShares);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: alice,
            minAssets: islandTokensReceived + 1
        });

        // Test
        vm.expectRevert("Zapper: insufficient assets received");
        vm.prank(bob);
        uint256 amountWithdrawn = zapperMock.publicWithdrawFromVault(redeemParams);
    }

    function test_withdrawFromVault_receiver_is_not_zapper() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);
        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // preview redeem
        uint256 islandTokensReceived = IERC4626(address(moneyBrinter)).previewRedeem(initialShares);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: alice,
            minAssets: islandTokensReceived
        });

        // Test
        vm.prank(bob);
        uint256 amountWithdrawn = zapperMock.publicWithdrawFromVault(redeemParams);

        // Assert
        assertEq(amountWithdrawn, islandTokensReceived, "Should withdraw same amount of island tokens");
        assertEq(
            IERC20(yeetIsland).balanceOf(alice),
            islandTokensReceived,
            "Alice should receive the same amount of island tokens"
        );
        assertEq(IERC20(yeetIsland).balanceOf(mockZapperAddress), 0, "Zapper should not receive any island tokens");
    }

    function test_withdrawFromVault_receiver_is_zapper() public {
        // Setup
        uint256 depositAmount = 1000e18;
        increaseAsset(bob, depositAmount);
        vm.prank(bob);
        IERC20(yeetIsland).approve(moneyBrinter, depositAmount);
        vm.prank(bob);
        uint256 initialShares = IERC4626(address(moneyBrinter)).deposit(depositAmount, bob);
        vm.prank(bob);
        IERC20(moneyBrinter).approve(mockZapperAddress, initialShares);

        // preview redeem
        uint256 islandTokensReceived = IERC4626(address(moneyBrinter)).previewRedeem(initialShares);

        IZapper.VaultRedeemParams memory redeemParams = IZapper.VaultRedeemParams({
            vault: address(moneyBrinter),
            shares: initialShares,
            receiver: mockZapperAddress,
            minAssets: islandTokensReceived
        });

        // Test
        vm.prank(bob);
        uint256 amountWithdrawn = zapperMock.publicWithdrawFromVault(redeemParams);

        // Assert
        assertEq(amountWithdrawn, islandTokensReceived, "Should withdraw same amount of island tokens");
        assertEq(
            IERC20(yeetIsland).balanceOf(mockZapperAddress),
            islandTokensReceived,
            "Zapper should receive the same amount of island tokens"
        );
    }

    function test_approveAndUnstakeFromKodiakVault_kodiakVault_not_whitelisted() public {
        // Setup
        address nonWhitelistedVault = address(0x123);
        uint256 islandTokenDebt = 1000e18;
        // send island tokens to zapper
        increaseAsset(bob, islandTokenDebt);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: nonWhitelistedVault,
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice
        });

        // Test
        vm.expectRevert();
        zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);
    }

    function test_approveAndUnstakeFromKodiakVault_receiver_is_zero_address() public {
        // Setup
        uint256 islandTokenDebt = 1000e18;
        increaseAsset(bob, islandTokenDebt);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);
        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: address(0)
        });

        // Test
        vm.expectRevert("Zapper: zero address beneficiary");
        zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);
    }

    function test_approveAndUnstakeFromKodiakVault_not_enough_island_tokens() public {
        // Setup
        uint256 islandTokenDebt = 1000e18;
        increaseAsset(bob, islandTokenDebt - 1);
        // vm.prank(bob);
        // IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice
        });

        // Test
        vm.expectRevert();
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 amount0, uint256 amount1) =
            zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);
    }

    function test_approveAndUnstakeFromKodiakVault_success_No_Debt() public {
        // Setup
        uint256 islandTokenDebt = 1000e18;
        increaseAsset(bob, islandTokenDebt);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice
        });

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 amount0, uint256 amount1) =
            zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);

        // Assert
        assertGt(amount0, 0, "Should receive some yeet");
        assertGt(amount1, 0, "Should receive some Wbera");
        assertEq(IERC20(yeet).balanceOf(alice), amount0, "Alice should receive yeet");
        assertEq(IERC20(Wbera).balanceOf(alice), amount1, "Alice should receive Wbera");
        // asseert zapper has 0 yeet and wbera
        assertEq(IERC20(yeet).balanceOf(mockZapperAddress), 0, "Zapper should not receive any yeet");
        assertEq(IERC20(Wbera).balanceOf(mockZapperAddress), 0, "Zapper should not receive any Wbera");

        // Check if remaining tokens were transferred to the receiver
        assertEq(IERC20(address(yeetIsland)).balanceOf(mockZapperAddress), 0, "Incorrect remaining tokens transferred");
    }

    function test_approveAndUnstakeFromKodiakVault_success_With_Debt_And_Receiver_Is_Zapper() public {
        // Setup
        uint256 islandTokenDebt = 1000e18;
        increaseAsset(bob, islandTokenDebt);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: mockZapperAddress
        });

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 amount0, uint256 amount1) =
            zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);

        // Assert
        assertGt(amount0, 0, "Should receive some yeet");
        assertGt(amount1, 0, "Should receive some Wbera");
        assertEq(IERC20(yeet).balanceOf(mockZapperAddress), amount0, "Zapper should receive yeet");
        assertEq(IERC20(Wbera).balanceOf(mockZapperAddress), amount1, "Zapper should receive Wbera");
        // asseert zapper has 0 yeet and wbera
        assertEq(IERC20(yeet).balanceOf(alice), 0, "Alice should not receive any yeet");
        assertEq(IERC20(Wbera).balanceOf(alice), 0, "Alice should not receive any Wbera");

        // Check if remaining tokens were transferred to the receiver
        assertEq(IERC20(address(yeetIsland)).balanceOf(mockZapperAddress), 0, "Incorrect remaining tokens transferred");
    }

    function test_approveAndUnstakeFromKodiakVault_success_With_Debt_And_Receiver_Is_Not_Zapper() public {
        // Setup
        uint256 islandTokenDebt = 1000e18;
        increaseAsset(bob, islandTokenDebt);
        vm.prank(bob);
        IERC20(yeetIsland).safeTransfer(mockZapperAddress, islandTokenDebt);

        IZapper.KodiakVaultUnstakingParams memory unstakeParams = IZapper.KodiakVaultUnstakingParams({
            kodiakVault: address(yeetIsland),
            amount0Min: 0,
            amount1Min: 0,
            receiver: alice
        });

        // Test
        vm.prank(bob);
        (IERC20 token0, IERC20 token1, uint256 amount0, uint256 amount1) =
            zapperMock.publicUnstakeFromIsland(unstakeParams, islandTokenDebt);

        // Assert
        assertGt(amount0, 0, "Should receive some yeet");
        assertGt(amount1, 0, "Should receive some Wbera");
        assertEq(IERC20(yeet).balanceOf(alice), amount0, "Alice should receive yeet");
        assertEq(IERC20(Wbera).balanceOf(alice), amount1, "Alice should receive Wbera");
        // asseert zapper has 0 yeet and wbera
        assertEq(IERC20(yeet).balanceOf(mockZapperAddress), 0, "Zapper should not receive any yeet");
        assertEq(IERC20(Wbera).balanceOf(mockZapperAddress), 0, "Zapper should not receive any Wbera");

        // Check if remaining tokens were transferred to the receiver
        assertEq(IERC20(address(yeetIsland)).balanceOf(mockZapperAddress), 0, "Incorrect remaining tokens transferred");
    }

    // Admin tests
    function test_setSwapRouter() public {
        address newSwapRouter = address(0x123);

        zapperMock.setSwapRouter(newSwapRouter);

        assertEq(address(zapperMock.swapRouter()), newSwapRouter, "SwapRouter should be updated");
    }

    function test_setSwapRouter_revertIfNotOwner() public {
        address newSwapRouter = address(0x123);
        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.setSwapRouter(newSwapRouter);
    }

    function test_setSwapRouter_revertIfZeroAddress() public {
        vm.expectRevert("Zapper: swapRouter is zero address");
        zapperMock.setSwapRouter(address(0));
    }

    function test_setCompoundingVault() public {
        address vault = address(0x456);
        zapperMock.setCompoundingVault(vault, true);
        assertTrue(zapperMock.whitelistedCompoundingVaults(vault), "Vault should be whitelisted");
        zapperMock.setCompoundingVault(vault, false);
        assertFalse(zapperMock.whitelistedCompoundingVaults(vault), "Vault should be removed from whitelist");
    }

    function test_setCompoundingVault_revertIfNotOwner() public {
        address vault = address(0x456);
        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.setCompoundingVault(vault, true);
    }

    function test_setCompoundingVault_revertIfZeroAddress() public {
        vm.expectRevert("Zapper: vault is zero address");
        zapperMock.setCompoundingVault(address(0), true);
    }

    function test_updateSwappableTokens() public {
        address token = address(0x789);

        zapperMock.updateSwappableTokens(token, true);

        assertTrue(zapperMock.whitelistedTokens(token), "Token should be whitelisted");

        zapperMock.updateSwappableTokens(token, false);

        assertFalse(zapperMock.whitelistedTokens(token), "Token should be removed from whitelist");
    }

    function test_updateSwappableTokens_revertIfNotOwner() public {
        address token = address(0x789);
        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.updateSwappableTokens(token, true);
    }

    function test_updateSwappableTokens_revertIfZeroAddress() public {
        vm.expectRevert("Zapper: token is zero address");
        zapperMock.updateSwappableTokens(address(0), true);
    }

    function test_setKodiakStakingRouter() public {
        address newRouter = address(0xabc);
        zapperMock.setKodiakStakingRouter(newRouter);
        assertEq(address(zapperMock.kodiakStakingRouter()), newRouter, "KodiakStakingRouter should be updated");
    }

    function test_setKodiakStakingRouter_revertIfNotOwner() public {
        address newRouter = address(0xabc);
        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.setKodiakStakingRouter(newRouter);
    }

    function test_setKodiakStakingRouter_revertIfZeroAddress() public {
        vm.expectRevert("Zapper: router is zero address");
        zapperMock.setKodiakStakingRouter(address(0));
    }

    function test_updateWhitelistedKodiakVault() public {
        address vault = address(0xdef);
        address token0 = address(0x111);
        address token1 = address(0x222);

        vm.mockCall(vault, abi.encodeWithSelector(IKodiakVaultV1.token0.selector), abi.encode(token0));
        vm.mockCall(vault, abi.encodeWithSelector(IKodiakVaultV1.token1.selector), abi.encode(token1));

        zapperMock.updateWhitelistedKodiakVault(vault, true);

        assertTrue(zapperMock.whitelistedKodiakVaults(vault), "Vault should be whitelisted");
        assertTrue(zapperMock.whitelistedTokens(token0), "Token0 should be whitelisted");
        assertTrue(zapperMock.whitelistedTokens(token1), "Token1 should be whitelisted");

        zapperMock.updateWhitelistedKodiakVault(vault, false);

        assertFalse(zapperMock.whitelistedKodiakVaults(vault), "Vault should be removed from whitelist");
    }

    function test_updateWhitelistedKodiakVault_revertIfNotOwner() public {
        address vault = address(0xdef);

        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.updateWhitelistedKodiakVault(vault, true);
    }

    function test_updateWhitelistedKodiakVault_revertIfZeroAddress() public {
        vm.expectRevert("Zapper: vault is zero address");
        zapperMock.updateWhitelistedKodiakVault(address(0), true);
    }

    function test_setReferralCode() public {
        uint32 newCode = 123;

        zapperMock.setReferralCode(newCode);

        assertEq(zapperMock.referralCode(), newCode, "Referral code should be updated");
    }

    function test_setReferralCode_revertIfNotOwner() public {
        uint32 newCode = 123;
        bytes memory error = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice);
        vm.expectRevert(error);
        vm.prank(alice);
        zapperMock.setReferralCode(newCode);
    }
}
