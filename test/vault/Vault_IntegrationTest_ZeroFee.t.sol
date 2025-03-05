// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ForkTest, Contracts} from "../ForkTest.sol";
import {IPlugin} from "../../src/interfaces/beradrome/IPlugin.sol";
import {IXKdkToken} from "../../src/interfaces/kodiak/IXKdkToken.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {VaultForkTest, VaultData, BeradromeRewardTokens} from "./VaultForkTest.sol";

import {ZapperForkTest} from "../zapper/ZapperForkTest.sol";
import {IZapper} from "../../src/interfaces/IZapper.sol";
import "forge-std/console.sol";

// import {FetchSwapData} from "../../script/FetchSwapData.s.sol";

contract Vault_IntegrationTest_ZeroFee is VaultForkTest, ZapperForkTest {
    uint256 token = 1e18;

    // FetchSwapData swapFetcher;

    function initContracts(uint256 forkBlockNumber) public override(VaultForkTest, ZapperForkTest) {
        initializeContracts(forkBlockNumber);
    }

    function setUp() public {
        uint256 forkBlockNumber = 3561079;
        initContracts(forkBlockNumber);
        vm.prank(admin);
        contracts.moneyBrinter.setExitFeeBasisPoints(0);
        vm.prank(admin);
        contracts.moneyBrinter.setAllocationFlagxKDK(true);
        // swapFetcher = new FetchSwapData();
    }

    // 1 Wbera = 70 yeet approx
    function test_Valid_Deposit_Into_Beradrome() public {
        uint256 maxYeet = 80 * token;
        uint256 maxWBera = 1 * token;

        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
    }

    function test_Multiple_Valid_Deposits() public {
        uint256 maxYeet = 80 * token;
        uint256 maxWBera = 1 * token;

        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);

        depositIntoVaultAndVerify(maxYeet, maxWBera, bob, bob);

        depositIntoVaultAndVerify(maxYeet, maxWBera, charlie, charlie);
    }

    // when no rewards.
    function test_Valid_Withdraw_From_Beradrome() public {
        // deposit into vault
        uint256 maxYeet = 80 * token;
        uint256 maxWBera = 1 * token;

        // @todo find min island tokens here and send to verify.
        (uint256 islands, uint256 brrs) = depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
        (uint256 brrsBurned, uint256 islandsGained) = redeemFromVaultAndVerify(alice, alice, alice, brrs, islands);
    }

    function test_Reward_Harvest_No_Allocation_xKDK() public {
        uint256 maxYeet = 80 * token;
        uint256 maxWBera = 1 * token;
        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
        depositIntoVaultAndVerify(maxYeet, maxWBera, bob, bob);
        depositIntoVaultAndVerify(maxYeet, maxWBera, charlie, charlie);
        fundYeet(bob, maxYeet * 3);
        fundWbera(bob, maxWBera * 3);
        (,, uint256 bobAssets) = depositIntoYeetIsland(bob, maxYeet * 3, maxWBera * 3);
        // deposit into farm
        vm.prank(bob);
        IERC20(yeetIsland).approve(beradromeFarmPlugin, bobAssets);
        vm.prank(bob);
        contracts.beradromeFarmPlugin.depositFor(bob, bobAssets);
        // increase time and block number
        increaseTimeAndBlock(1 days, 1 days); // assuming 1 sec per block
        // harvest plugin rewards
        contracts.beradromeFarmPlugin.claimAndDistribute();
        BeradromeRewardTokens memory bobRewardsEarned = _getRewardsEarned(bob);
        BeradromeRewardTokens memory vaultRewardsEarned = _getRewardsEarned(moneyBrinter);
        BeradromeRewardTokens memory vaultBalancesInitial = _getRewardTokenBalance(moneyBrinter);
        // check accrued token rewards for vault work just like any other user.
        assertEq(bobRewardsEarned.kdk, vaultRewardsEarned.kdk);
        assertEq(bobRewardsEarned.xKdk, vaultRewardsEarned.xKdk);
        assertEq(bobRewardsEarned.oBero, vaultRewardsEarned.oBero);
        vm.prank(admin);
        contracts.moneyBrinter.setAllocationFlagxKDK(false);
        // harvest vault rewards
        contracts.moneyBrinter.harvestBeradromeRewards();
        BeradromeRewardTokens memory vaultRewardsAfterHarvest = _getRewardsEarned(moneyBrinter);
        BeradromeRewardTokens memory vaultBalancesFinal = _getRewardTokenBalance(moneyBrinter);
        _verifyBeradromeRewardsHarvest(
            0, vaultRewardsEarned, vaultRewardsAfterHarvest, vaultBalancesInitial, vaultBalancesFinal
        );
    }

    function test_xKDK_Allocation() public {
        uint256 maxYeet = 1000 * token;
        uint256 maxWBera = 100 * token;
        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
        // increase time and block number
        increaseTimeAndBlock(1 days, 0);
        // harvest berdrome plugin rewards
        contracts.beradromeFarmPlugin.claimAndDistribute();
        BeradromeRewardTokens memory vaultRewards = BeradromeRewardTokens({
            // check accrued token rewards.
            kdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, kdk),
            xKdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, xKdk),
            oBero: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, oBero)
        });
        // get allocation of xKDK before harvest
        uint256 xKdkAllocatedInitially = IXKdkToken(xKdk).usageAllocations(moneyBrinter, kodiakRewards);
        // make sure xKDK allocation flag is set
        vm.prank(admin);
        contracts.moneyBrinter.setAllocationFlagxKDK(true);
        contracts.moneyBrinter.harvestBeradromeRewards();
        contracts.moneyBrinter.harvestKodiakRewards(new address[](0));
        uint256 finalxKdkAllocated = IXKdkToken(xKdk).usageAllocations(moneyBrinter, kodiakRewards);
        assertEq(finalxKdkAllocated - xKdkAllocatedInitially, vaultRewards.xKdk, "xKDK not allocated on harvest");
        uint256 xKdkBalance = IERC20(xKdk).balanceOf(moneyBrinter);
        console.log("xKDK Balance: ", xKdkBalance);
        assertEq(xKdkBalance, 0, "xKDK balance not zero");
    }

    function test_xKDK_Allocation_Rewards_Harvest() public {
        uint256 maxYeet = 1000 * token;
        uint256 maxWBera = 100 * token;
        depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
        // increase time and block number
        increaseTimeAndBlock(1 days, 0);
        // harvest berdrome plugin rewards
        contracts.beradromeFarmPlugin.claimAndDistribute();
        contracts.moneyBrinter.harvestBeradromeRewards();
        contracts.moneyBrinter.harvestKodiakRewards(new address[](0));
        // get list of all reward tokens
        address[] memory rewardTokens = _getKodiakRewardTokens();
        // increase time and block number
        increaseTimeAndBlock(1 weeks, 0);
        uint256[] memory initBalanceVault = _getVaultTokenBalances(rewardTokens);
        uint256[] memory initEarned = _getPendingKodiakRewardsForVault(rewardTokens);
        // harvest and check if all rewards are claimed
        contracts.moneyBrinter.harvestKodiakRewards(new address[](0));
        uint256[] memory pendingRewardsAfterHarvest = _getPendingKodiakRewardsForVault(rewardTokens);
        uint256[] memory finalVaultBalances = _getVaultTokenBalances(rewardTokens);
        _verifyKodiakRewardHarvest(
            rewardTokens, initEarned, pendingRewardsAfterHarvest, initBalanceVault, finalVaultBalances
        );
    }

    function test_Reward_Compound_Beradrome_Only() public {
        uint256 maxYeet = 80 * token;
        uint256 maxWBera = 1 * token;
        _makeMultipleDeposits(maxYeet, maxWBera);
        // increase time and block number
        increaseTimeAndBlock(2 days, 0);
        // harvest plugin rewards
        contracts.beradromeFarmPlugin.claimAndDistribute();
        VaultData memory initialVaultData = _getVaultData();
        // claim rewards
        contracts.moneyBrinter.harvestBeradromeRewards();
        uint256 totalKdk = IERC20(kdk).balanceOf(moneyBrinter);
        uint256 totalOBero = IERC20(oBero).balanceOf(moneyBrinter);

        (
            address[] memory swapInputTokens,
            IZapper.SingleTokenSwap[] memory swapToToken0,
            IZapper.SingleTokenSwap[] memory swapToToken1
        ) = _getStaticSwapData();

        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
        _prepareStakingParamsWithSlippage(
            swapToToken0[0].outputMin + swapToToken0[1].outputMin,
            swapToToken1[0].outputMin + swapToToken1[1].outputMin,
            1500
        );
        uint256 minAssetsRecieved = IERC4626(moneyBrinter).previewRedeem(minVaultShares);
        // override receiver to get island tokens to vault
        stakingParams.receiver = moneyBrinter;
        IZapper.VaultDepositParams memory depositParams;

        vm.prank(strategyManager);
        uint256 compoundAmount =
            contracts.moneyBrinter.compound(swapInputTokens, swapToToken0, swapToToken1, stakingParams, depositParams);

        // After compound.
        // extra rewards of kdk, oBero are left in vault's possession
        assertEq(
            totalKdk - IERC20(kdk).balanceOf(moneyBrinter), swapToToken0[0].inputAmount + swapToToken1[0].inputAmount
        );
        assertEq(
            totalOBero - IERC20(oBero).balanceOf(moneyBrinter),
            swapToToken0[1].inputAmount + swapToToken1[1].inputAmount
        );

        VaultData memory finalVaultData = _getVaultData();

        _verifyCompound(minAssetsRecieved, compoundAmount, initialVaultData, finalVaultData);
        // check zapper zero balances
        verifyNoBalanceInZapper();
    }

    function _prepareStakingParamsWithSlippage(uint256 maxToken0ForStake, uint256 maxToken1ForStake, uint256 slippage)
        internal
        view
        returns (IZapper.KodiakVaultStakingParams memory, uint256)
    {
        uint256 minToken0ForStake = maxToken0ForStake - (maxToken0ForStake * slippage) / 10000;
        uint256 minToken1ForStake = maxToken1ForStake - (maxToken1ForStake * slippage) / 10000;
        (IZapper.KodiakVaultStakingParams memory stakingParams, uint256 minVaultShares) =
            prepareStakingParams(maxToken0ForStake, maxToken1ForStake, minToken0ForStake, minToken1ForStake);
        return (stakingParams, minVaultShares);
    }

    function _getStaticSwapData()
        internal
        view
        returns (
            address[] memory swapInputTokens,
            IZapper.SingleTokenSwap[] memory swapToToken0,
            IZapper.SingleTokenSwap[] memory swapToToken1
        )
    {
        IZapper.SingleTokenSwap memory kdkSwap0 = prepareSwapInfo(
            1241848880074523,
            530875648416222464,
            520258135447898014,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A40101fd27998fa0eaB1A6372Db14Afd4bF7c4a58C536401ffff014A356D7b0EAe87bec76890753488b738d298c66D00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d017507c1dc16935B82698e4C63f2746A2fCf994dF8032aac011Bf4b5c1FF6edB071Cc19FECb8E45A6a7c3F68b200Da547d8ce09e23E9e8053dd187B58841B5fB8D5dccc90046e0d0832bb4E6743249adC4E22B405bF27bd0A101Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff01fb8a94Ed23a2370f36739f715081397f62329aa201Da547d8ce09e23E9e8053dd187B58841B5fB8D5d018F22CD288fa62F5F198ba03fCdb3829DD7C0cbb802dffe016f77F9B6bA144c48E8Fc529D43349aEfD4340aa500Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01fE39610cc7B8b1862B21475C2d83dC2FE760b93301544f41D2c6aA0aE76a8CFf3b56B4e99959FA1cB604DFDaeCa74bB2D37204171Ce05fE6bA6AE970D84400544f41D2c6aA0aE76a8CFf3b56B4e99959FA1cB600Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE702800701cFaba0f94551db14c6D4e559Cb7834eE7C90940801Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01Dd9f7845bDCb206eC4D3475fA6d5558D4A2024C401Da547d8ce09e23E9e8053dd187B58841B5fB8D5d01a0525273423537BC76825B4389F3bAeC1968f83F01ffff01521b030A9745D8A5c81A8618743DFC04d03d962A01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d01d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c02becc0164F18443596880Df5237411591Afe7Ae69f9e9B900Da547d8ce09e23E9e8053dd187B58841B5fB8D5dffff00d689e771139295538e16Ba265775a6ca845600a001F365dC3cd795fa7A03b0F1758b020FdDc87509eB000bb804E28AfD8c634946833e89ee3F122C06d7C537E8A800F365dC3cd795fa7A03b0F1758b020FdDc87509eB00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8010E4aaF1351de4c0264C5c7056Ef3777b41BD8e030228c301A4570838F70eaBb33bc60a0400a33bd513478BE001FD790C86B0aAd6227BA45e0040618e46B5d2caE9ffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb804355bb949d80331516Fc7F4CF81229021187d67d200FD790C86B0aAd6227BA45e0040618e46B5d2caE900Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );
        IZapper.SingleTokenSwap memory kdkSwap1 = prepareSwapInfo(
            1241848880074523,
            3851427648771225,
            3774399095795800, // real outcome to confer with the test
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A40101fd27998fa0eaB1A6372Db14Afd4bF7c4a58C536401ffff014A356D7b0EAe87bec76890753488b738d298c66D00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory oBeroSwap0 = prepareSwapInfo(
            2901912369261689,
            795057918828712308,
            779156760452138061,
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x1740F679325ef3686B2f574e392007A92e4BeD417bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017629668774f918c00Eb4b03AdF5C4e2E53d45f0b03155501af24Bf8eFaC901b2df7BD95F1f04544ae37EDB3400Da547d8ce09e23E9e8053dd187B58841B5fB8D5dd17400fEdc76E268ec5e6D3a360d2f4BC42fF658D85E2E0046e0d0832bb4E6743249adC4E22B405bF27bd0A1000bb8ffff0049548a2345ef82699ad3858974E2E2815f1a44c6013446FE5bEf989741F86E42551d45Fe28Dc38804E000bb804802762e604CE08a79DA2BA809281D727A690Fa0d003446FE5bEf989741F86E42551d45Fe28Dc38804E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0303144401A4570838F70eaBb33bc60a0400a33bd513478BE001Da547d8ce09e23E9e8053dd187B58841B5fB8D5d34850bAd1782b2a7020631249031618fB1Bd09CD926b31806Ef538b228844c73E8E692ADCFa8Eb2fCF729cDa547d8ce09e23E9e8053dd187B58841B5fB8D5dffff01246c12D7F176B93e32015015dAB8329977de981B011E55c4C69acAeb49b2834FF5Bc5D8De5d716B39004f5AFCF50006944d17226978e594D4D25f4f92B40001E55c4C69acAeb49b2834FF5Bc5D8De5d716B39000Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb801806Ef538b228844c73E8E692ADCFa8Eb2fCF729c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca2007507c1dc16935B82698e4C63f2746A2fCf994dF846e0d0832bb4E6743249adC4E22B405bF27bd0A101355bb949d80331516Fc7F4CF81229021187d67d202767000FD790C86B0aAd6227BA45e0040618e46B5d2caE900Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff00fA657f06A9d6FE4065b715EFE5cC409e5A453194009F8028150519Dd4FD792F3476C4b2046AC0FF5cd000bb8041E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE7009F8028150519Dd4FD792F3476C4b2046AC0FF5cd0146e0d0832bb4E6743249adC4E22B405bF27bd0A1000bb8047507c1dc16935B82698e4C63f2746A2fCf994dF80046e0d0832bb4E6743249adC4E22B405bF27bd0A101Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8018F22CD288fa62F5F198ba03fCdb3829DD7C0cbb801ffff011E0218224090feC35772baf9FA8FB377e55d005700Da547d8ce09e23E9e8053dd187B58841B5fB8D5d"
            )
        );
        IZapper.SingleTokenSwap memory oBeroSwap1 = prepareSwapInfo(
            2901912369261689,
            10240971825357180,
            8379953716443087, // real outcome to confer with the test
            // 10036152388850036, // api value
            0xDa547d8ce09e23E9e8053dd187B58841B5fB8D5d,
            vm.parseBytes(
                "0x7507c1dc16935B82698e4C63f2746A2fCf994dF87bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A401017629668774f918c00Eb4b03AdF5C4e2E53d45f0b03155501af24Bf8eFaC901b2df7BD95F1f04544ae37EDB3400fA657f06A9d6FE4065b715EFE5cC409e5A453194d17400fEdc76E268ec5e6D3a360d2f4BC42fF658D85E2E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8ffff0049548a2345ef82699ad3858974E2E2815f1a44c6013446FE5bEf989741F86E42551d45Fe28Dc38804E000bb804802762e604CE08a79DA2BA809281D727A690Fa0d003446FE5bEf989741F86E42551d45Fe28Dc38804E00Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0301ffff0bAd1782b2a7020631249031618fB1Bd09CD926b31806Ef538b228844c73E8E692ADCFa8Eb2fCF729cDa547d8ce09e23E9e8053dd187B58841B5fB8D5d01806Ef538b228844c73E8E692ADCFa8Eb2fCF729c01ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca2007507c1dc16935B82698e4C63f2746A2fCf994dF8Da547d8ce09e23E9e8053dd187B58841B5fB8D5d04355bb949d80331516Fc7F4CF81229021187d67d200fA657f06A9d6FE4065b715EFE5cC409e5A453194009F8028150519Dd4FD792F3476C4b2046AC0FF5cd000bb8041E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE7009F8028150519Dd4FD792F3476C4b2046AC0FF5cd01Da547d8ce09e23E9e8053dd187B58841B5fB8D5d000bb8"
            )
        );

        swapInputTokens = new address[](4);
        swapInputTokens[0] = kdk;
        swapInputTokens[1] = oBero;
        // swapInputTokens[1] = kdk;
        swapInputTokens[2] = kdk;
        swapInputTokens[3] = oBero;
        swapToToken0 = new IZapper.SingleTokenSwap[](2);
        swapToToken1 = new IZapper.SingleTokenSwap[](2);

        swapToToken0[0] = kdkSwap0;
        swapToToken0[1] = oBeroSwap0;
        swapToToken1[0] = kdkSwap1;
        swapToToken1[1] = oBeroSwap1;
    }

    // function test_Reward_Compound_Dynamic() public {
    //     console.log("block number", block.number, block.timestamp);
    //     uint maxYeet = 80 * token;
    //     uint maxWBera = 1 * token;
    //     console.log("deposit 0");
    //     depositIntoVaultAndVerify(maxYeet, maxWBera, alice, alice);
    //     console.log("deposit 1");
    //     depositIntoVaultAndVerify(maxYeet, maxWBera, bob, bob);
    //     console.log("deposit 2");
    //     depositIntoVaultAndVerify(maxYeet, maxWBera, charlie, charlie);
    //     console.log("Depositing for Bob");
    //     // increase time and block number
    //     increaseTimeAndBlock(1 days, 1 days); // assuming 1 sec per block
    //     // harvest plugin rewards
    //     contracts.beradromeFarmPlugin.claimAndDistribute();
    //     BeradromeRewardTokens memory vaultRewards = BeradromeRewardTokens({
    //         // check accrued token rewards.
    //         kdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, kdk),
    //         xKdk: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, xKdk),
    //         oBero: contracts.beradromeFarmRewardsGauge.earned(moneyBrinter, oBero)
    //     });
    //     uint vaultInitialAssets = IERC4626(moneyBrinter).totalAssets();
    //     address[] memory previousKodiakRewardTokens = new address[](0);

    //     // claim rewards
    //     contracts.moneyBrinter.harvestRewards(true, true, previousKodiakRewardTokens);

    //     uint totalKdk = IERC20(kdk).balanceOf(moneyBrinter);
    //     uint totalOBero = IERC20(oBero).balanceOf(moneyBrinter);

    //     (uint inputAmount, uint outputQuote, uint outputMin, address executor, string memory path) = swapFetcher.getSwapData(kdk, yeet, totalKdk / 2, zapper);
    //     IZapper.SingleTokenSwap memory kdkSwap0 = prepareSwapInfo(inputAmount, outputQuote, outputMin / 2, executor, vm.parseBytes(path));
    //     (uint inputAmount1, uint outputQuote1, uint outputMin1, address executor1, string memory path1) = swapFetcher.getSwapData(kdk, Wbera, totalKdk / 2, zapper);
    //     IZapper.SingleTokenSwap memory kdkSwap1 = prepareSwapInfo(inputAmount1, outputQuote1, outputMin1 / 2, executor1, vm.parseBytes(path1));

    //     address[] memory swapInputTokens = new address[](2);
    //     swapInputTokens[0] = kdk;
    //     swapInputTokens[1] = kdk;
    //     // swapInputTokens[1] = oBero;
    //     // swapInputTokens[2] = kdk;
    //     // swapInputTokens[3] = oBero;
    //     IZapper.SingleTokenSwap[] memory swapToToken0 = new IZapper.SingleTokenSwap[](1);
    //     IZapper.SingleTokenSwap[] memory swapToToken1 = new IZapper.SingleTokenSwap[](1);

    //     swapToToken0[0] = kdkSwap0;
    //     swapToToken1[0] = kdkSwap1;
    //     // swapToToken0[1] = oBeroSwap0;
    //     // swapToToken1[1] = oBeroSwap1;
    //     uint maxToken0ForStake = swapToToken0[0].outputMin / 2 /* + swapToToken0[1].outputMin */;
    //     uint maxToken1ForStake = swapToToken1[0].outputMin / 2 /* + swapToToken1[1].outputMin */;
    //     // lets allow 2% slippage
    //     uint minToken0ForStake = maxToken0ForStake - (maxToken0ForStake * 2) / 100;
    //     uint minToken1ForStake = maxToken1ForStake - (maxToken1ForStake * 2) / 100;

    //     (IZapper.KodiakVaultStakingParams memory stakingParams, uint minAssetsRecvd) = prepareStakingParams(maxToken0ForStake, maxToken1ForStake, minToken0ForStake, minToken1ForStake);
    //     // override receiver to get island tokens to vault
    //     stakingParams.receiver = moneyBrinter;
    //     IZapper.VaultDepositParams memory depositParams;

    //     vm.prank(strategyManager);
    //     uint compoundAmount = contracts.moneyBrinter.compound(swapInputTokens, swapToToken0, swapToToken1, stakingParams, depositParams);
    //     console.log("Compound Amount: ", compoundAmount);

    //     // After compound.
    //     // extra rewards of kdk, oBero are left in vault's possession
    //     assertEq(totalKdk - IERC20(kdk).balanceOf(moneyBrinter), kdkSwap0.inputAmount + kdkSwap1.inputAmount);
    //     // assertEq(totalOBero - IERC20(oBero).balanceOf(moneyBrinter), oBeroSwap0.inputAmount + oBeroSwap1.inputAmount);
    //     // xKDK is allocated based on flag
    //     // vault total assets are increased by a min of minAssetsRecvd
    //     assertGe(IERC4626(moneyBrinter).totalAssets(), minAssetsRecvd + vaultInitialAssets);
    // }
}
