// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IComplexZapper {
    struct ZapInParams {
        uint256 inputAmount;
        uint256 outputQuote;
        uint256 outputMin;
        address executor;
        bytes path;
    }

    struct ZapOutParams {
        uint256 inputAmount;
        uint256 outputQuote;
        uint256 outputMin;
        address executor;
        bytes path;
    }

    struct KodiakWithdrawParams {
        address kodiakVault;
        uint256 amount0Min;
        uint256 amount1Min;
        address receiver;
    }

    struct VaultWithdrawParams {
        address vault;
        address receiver;
        uint256 shares;
        uint256 minAssets;
    }

    struct KodiakDepositParams {
        address kodiakVault;
        uint256 amount0Max;
        uint256 amount1Max;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 amountSharesMin;
        address receiver;
    }

    struct VaultDepositParams {
        address vault;
        address receiver;
        uint256 minShares;
    }

    function zapIn(
        address inputToken,
        ZapInParams calldata params0,
        ZapInParams calldata params1,
        KodiakDepositParams calldata kodiakParams,
        VaultDepositParams calldata vaultParams
    ) external payable;

    function zapInNative(
        ZapInParams calldata params0,
        ZapInParams calldata params1,
        KodiakDepositParams calldata kodiakParams,
        VaultDepositParams calldata vaultParams
    ) external payable;


    function whitelistedKodiakVaults(address) external view returns (bool);

    function zapInToken1(
        ZapInParams calldata swapData,
        KodiakDepositParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256 vaultAssetsReceived, uint256 vaultSharesMinted);

    function zapInToken0(
        ZapInParams calldata swapData,
        KodiakDepositParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256 vaultAssetsReceived, uint256 vaultSharesMinted);

    function zapOut(
        address outputToken,
        address receiver,
        ZapOutParams calldata params0,
        ZapOutParams calldata params1,
        KodiakWithdrawParams calldata kodiakParams,
        VaultWithdrawParams calldata vaultParams
    ) external payable;

    function zapOutToToken1(
        address receiver,
        ZapOutParams calldata swapData,
        KodiakWithdrawParams calldata kodiakParams,
        VaultWithdrawParams calldata vaultParams
    ) external returns (uint256 totalToken1Out);

    function claimRewardsInToken1(
        uint256 amountToWithdraw,
        ZapInParams memory zapParams,
        KodiakWithdrawParams memory kodiakParams,
        VaultWithdrawParams memory vaultParams
    ) external;

    function compound(
        address[] calldata swapInputTokens,
        ZapInParams[] calldata zapParamsToken0,
        ZapInParams[] calldata zapParamsToken1,
        KodiakDepositParams calldata kodiakParams,
        VaultDepositParams calldata vaultParams
    ) external;
}


contract ClaimRewardsTest is Test {
    address constant SENDER = 0x9a19c70e83cc714987ff36E3F831968e6A31D00A;

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", 8856923);
        vm.startPrank(SENDER);
    }


    function testClaimRewardsInToken1() public {
        uint256 amountToWithdraw = 652039337786711278300000;

        // ZapInParams structure
        IComplexZapper.ZapInParams memory zapParams = IComplexZapper.ZapInParams({
            inputAmount: 518185313669450638,
            outputQuote: 82266970739940360192,
            outputMin: 81444301032540956590,
            executor: 0x16AF8dFE7584C94e04c764CA004B5D5feB72fA9f,
            path: hex"8c245484890a61Eb2d1F81114b1a7216dCe2752b0000000000000000000000000000000000000000000000000475aefe04d5998000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000475aefe04d5998000017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff014844423484917838AF84bE5FF81729eA62C220120116AF8dFE7584C94e04c764CA004B5D5feB72fA9f"
        });

        // KodiakWithdrawParams structure
        IComplexZapper.KodiakWithdrawParams memory kodiakParams = IComplexZapper.KodiakWithdrawParams({
            kodiakVault: 0x0001513F4a1f86da0f02e647609E9E2c630B3a14,
            amount0Min: 516110497598702087,
            amount1Min: 82522081666127661623,
            receiver: 0xCf87EB9215DD67AfF4771bbC76E34339893e19FD
        });

        // VaultWithdrawParams structure
        IComplexZapper.VaultWithdrawParams memory vaultParams = IComplexZapper.VaultWithdrawParams({
            vault: 0xFD0e3cA913Ce00528CB93b0A8A80AABfEDF54970,
            receiver: 0xCf87EB9215DD67AfF4771bbC76E34339893e19FD,
            shares: 0,
            minAssets: 6487791410977777219
        });

        // Instance of the contract we're testing
        IComplexZapper zapper = IComplexZapper(0x9Fff036b6f7A73d4f8B5B3D54018C95650E13b10);

        vm.stopPrank();
        vm.startPrank(address(zapper));
        IERC20(vaultParams.vault).approve(
            address(0xCf87EB9215DD67AfF4771bbC76E34339893e19FD),
            amountToWithdraw  // Use exact amount: 652039337786711278300000
        );
        vm.stopPrank();
        vm.startPrank(SENDER);

        try zapper.claimRewardsInToken1(
            amountToWithdraw,
            zapParams,
            kodiakParams,
            vaultParams
        ) {
            console.log("Success!");
        } catch Error(string memory reason) {
            console.log("Failed:", reason);
            revert("Failed");
        } catch (bytes memory lowLevelData) {
            if (bytes4(lowLevelData) == bytes4(0xf4d678b8)) {
                console.log("Failed with native token error");
            }
            console.log("Low level error:");
            console.logBytes(lowLevelData);
            revert("Low level error");
        }
    }
}

contract ClaimRewardsTestA is Test {
    address constant SENDER = 0x9a19c70e83cc714987ff36E3F831968e6A31D00A;

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", 9150618);
        vm.startPrank(SENDER);
    }

    function testClaimRewardsInToken1a() public {
        uint256 amountToWithdraw = 67123272726866233078193000;

        // ZapInParams structure
        IComplexZapper.ZapInParams memory zapParams = IComplexZapper.ZapInParams({
            inputAmount: 176070635749232479963,
            outputQuote: 2610260405655285268480,
            outputMin: 2584157801598732415795,
            executor: 0x92Bfc41b2980131386629E67253387cDc5754c04,
            path: hex"8c245484890a61Eb2d1F81114b1a7216dCe2752b0000000000000000000000000000000000000000000000008d80a3d930ee500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008d80a3d930ee500000017507c1dc16935B82698e4C63f2746A2fCf994dF801ffff014844423484917838AF84bE5FF81729eA62C220120192bfc41b2980131386629e67253387cdc5754c04"
        });

        // KodiakWithdrawParams structure
        IComplexZapper.KodiakWithdrawParams memory kodiakParams = IComplexZapper.KodiakWithdrawParams({
            kodiakVault: 0x0001513F4a1f86da0f02e647609E9E2c630B3a14,
            amount0Min: 175365648218705022586,
            amount1Min: 2634092788755552196968,
            receiver: 0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E
        });

        // VaultWithdrawParams structure
        IComplexZapper.VaultWithdrawParams memory vaultParams = IComplexZapper.VaultWithdrawParams({
            vault: 0x208008F377Ad00ac07A646A1c3eA6b70eB9Fc511,
            receiver: 0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E,
            shares: 0,
            minAssets: 667876563632319019127
        });

        // Instance of the contract we're testing
        IComplexZapper zapper = IComplexZapper(0xE25783d8dccc7bAab13784D9710c90F1E5348cf5);

        vm.stopPrank();
        vm.startPrank(address(zapper));
        IERC20(vaultParams.vault).approve(
            address(0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E),
            amountToWithdraw
        );
        vm.stopPrank();
        vm.startPrank(SENDER);

        try zapper.claimRewardsInToken1(
            amountToWithdraw,
            zapParams,
            kodiakParams,
            vaultParams
        ) {
            console.log("Success!");
        } catch Error(string memory reason) {
            console.log("Failed:", reason);
            revert("Failed");
        } catch (bytes memory lowLevelData) {
            if (bytes4(lowLevelData) == bytes4(0xf4d678b8)) {
                console.log("Failed with native token error");
            }
            console.log("Low level error:");
            console.logBytes(lowLevelData);
            revert("Low level error");
        }
    }
}

//contract ZapInNativeTest is Test {
//    address constant SENDER = 0x6D1aFC330423eF0F1ee696706a22bb1e81cd3beA;
//
//    function setUp() public {
//        vm.createSelectFork("https://rpc.berachain.com/", 1006111);
//        vm.startPrank(SENDER);
//    }
//
//    function testZapInNative() public {
//        // Instance of the contract we're testing
//        IComplexZapper zapper = IComplexZapper(0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc);
//
//        // ZapInParams structure for params0
//        IComplexZapper.ZapInParams memory params0 = IComplexZapper.ZapInParams({
//            inputAmount: 39922878232483823,
//            outputQuote: 20717306419259342848,
//            outputMin: 20095787226681562562,
//            executor: 0xa154CCD02848068ceC1c16B3126EBb2BE73553Ed,
//            path: hex"08A38Caa631DE329FF2DAD1656CE789F31AF3142000000000000000000000000000000000000000000000000011f82a86c5edf800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011f82a86c5edf800001696969696969696969696969696969696969696901ffff01f065f7cCf54Ef8596FE77A4836d963d5aF84EB5d00a154CCD02848068ceC1c16B3126EBb2BE73553Ed"
//        });
//
//        // ZapInParams structure for params1 (empty params)
//        IComplexZapper.ZapInParams memory params1 = IComplexZapper.ZapInParams({
//            inputAmount: 0,
//            outputQuote: 0,
//            outputMin: 0,
//            executor: address(0),
//            path: hex"0000000000000000000000000000000000000000"
//        });
//
//        // KodiakDepositParams structure
//        IComplexZapper.KodiakDepositParams memory kodiakParams = IComplexZapper.KodiakDepositParams({
//            kodiakVault: 0xEc8BA456b4e009408d0776cdE8B91f8717D13Fa1,
//            amount0Max: 20095787226681562562,
//            amount1Max: 60077121767516177,
//            amount0Min: 17836053802529286971,
//            amount1Min: 59175964941003434,
//            amountSharesMin: 789329808002638008,
//            receiver: 0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc
//        });
//
//        // VaultDepositParams structure
//        IComplexZapper.VaultDepositParams memory vaultParams = IComplexZapper.VaultDepositParams({
//            vault: 0xD3908dA797eCeC7ea0fBfbacF3118302E215556c,
//            receiver: 0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc,
//            minShares: 78932980800263800800000
//        });
//
//        try zapper.zapInNative{value: params0.inputAmount}(
//            params0,
//            params1,
//            kodiakParams,
//            vaultParams
//        ) {
//            console.log("Success!");
//        } catch Error(string memory reason) {
//            console.log("Failed:", reason);
//            revert("Failed");
//        } catch (bytes memory lowLevelData) {
//            console.log("Low level error:");
//            console.logBytes(lowLevelData);
//            revert("Low level error");
//        }
//    }
//}


//contract ComplexZapperTest is Test {
//    address constant SENDER = 0x9a19c70e83cc714987ff36E3F831968e6A31D00A;
//
//    function setUp() public {
//        vm.createSelectFork("https://bartio.rpc.berachain.com/", 9707041);
//        vm.startPrank(SENDER);
//    }
//
//    function testZapIn() public {
//        IComplexZapper zapper = IComplexZapper(0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E);
//
////        0000000000000000000000000000000000000000000000000943741ac0937849
////        0000000000000000000000000000000000000000000000000a47d9f48073acff // min outPut
//
//        IComplexZapper.ZapInParams memory params0 = IComplexZapper.ZapInParams({
//            inputAmount: 4829717134411638690,
//            outputQuote: 748283139268735482,
//            outputMin:   800307876048127,
//            executor: 0x92Bfc41b2980131386629E67253387cDc5754c04,
//            path: hex"7507c1dc16935B82698e4C63f2746A2fCf994dF8010000000000000000000000000000000000000000000000000a626f8cf386f1fa00000000000000000000000000000000000000000000000009a71c168dd72c0000000000000000000000000000000000000000000000000009cd07f9cffb1a00010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0303155500f94D4cDFC1C0FFF801C93E4F7714c6d3d240308E0192bfc41b2980131386629e67253387cdc5754c04000bb8174600A4969eF78547B1c4bD1c739AE9C86EE50eBaa60a0192bfc41b2980131386629e67253387cdc5754c04000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca00146eFC86F0D7455F135CC9df501673739d513E98284dfeAd1781c89ee0914eAbd526994C7A5c04d59012577D24a26f8FA19c1058a8b0106E2c7303454a401ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca001a0525273423537BC76825B4389F3bAeC1968f83F92bfc41b2980131386629e67253387cdc5754c04011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE701ffff01cFaba0f94551db14c6D4e559Cb7834eE7C9094080192bfc41b2980131386629e67253387cdc5754c0401a0525273423537BC76825B4389F3bAeC1968f83F0280de002A651799B87D113845265184beAc42a0cBB5a4070092bfc41b2980131386629e67253387cdc5754c04000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca201d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c92bfc41b2980131386629e67253387cdc5754c0401d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c02384200D2B6F16c667AE3bA87a726777a726b7fb8e63F4f0084dfeAd1781c89ee0914eAbd526994C7A5c04d59000bb8ffff00692bB44820568223798f2577D092BAf0d696dd470092bfc41b2980131386629e67253387cdc5754c04000bb80446eFC86F0D7455F135CC9df501673739d513E9820084dfeAd1781c89ee0914eAbd526994C7A5c04d590192bfc41b2980131386629e67253387cdc5754c04000bb801fc5e3743E9FAC8BB60408797607352E24Db7d65E02e7b300654f5dbd25191406eBA93A7Cf16A092F495aff990092bfc41b2980131386629e67253387cdc5754c04000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0007507c1dc16935B82698e4C63f2746A2fCf994dF892bfc41b2980131386629e67253387cdc5754c04011740F679325ef3686B2f574e392007A92e4BeD4101ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF892bfc41b2980131386629e67253387cdc5754c04"
//        });
//
//        IComplexZapper.ZapInParams memory params1 = IComplexZapper.ZapInParams({
//            inputAmount: 5170282865588361310,
//            outputQuote: 21263824351982875690,
//            outputMin:   51186108463046933,
//            executor: 0x92Bfc41b2980131386629E67253387cDc5754c04,
//            path: hex"8c245484890a61Eb2d1F81114b1a7216dCe2752b01000000000000000000000000000000000000000000000001271847966a3d742a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001150578a8012e4000010E4aaF1351de4c0264C5c7056Ef3777b41BD8e0303155500f94D4cDFC1C0FFF801C93E4F7714c6d3d240308E0192bfc41b2980131386629e67253387cdc5754c04000bb8174600A4969eF78547B1c4bD1c739AE9C86EE50eBaa60a0192bfc41b2980131386629e67253387cdc5754c04000bb8ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca00146eFC86F0D7455F135CC9df501673739d513E98284dfeAd1781c89ee0914eAbd526994C7A5c04d59012577D24a26f8FA19c1058a8b0106E2c7303454a401ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca001a0525273423537BC76825B4389F3bAeC1968f83F92bfc41b2980131386629e67253387cdc5754c04011E94a8ceE3E5bD97e0cD933B8F8537fC3Db4FcE701ffff01cFaba0f94551db14c6D4e559Cb7834eE7C9094080192bfc41b2980131386629e67253387cdc5754c0401a0525273423537BC76825B4389F3bAeC1968f83F02810301595b50Bf6ce477566602dfe011c13C1e9F91BE0300590dfAec188c567D649ebb4f46e0Df79939D65E0ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca201d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727cD2B6F16c667AE3bA87a726777a726b7fb8e63F4f04d6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c00D2B6F16c667AE3bA87a726777a726b7fb8e63F4f0084dfeAd1781c89ee0914eAbd526994C7A5c04d59000bb80446eFC86F0D7455F135CC9df501673739d513E9820084dfeAd1781c89ee0914eAbd526994C7A5c04d5901654f5dbd25191406eBA93A7Cf16A092F495aff99000bb804fc5e3743E9FAC8BB60408797607352E24Db7d65E00654f5dbd25191406eBA93A7Cf16A092F495aff990092bfc41b2980131386629e67253387cdc5754c04000bb8011740F679325ef3686B2f574e392007A92e4BeD4101ffff0a21e2C0AFd058A89FCf7caf3aEA3cB84Ae977B73D0000000000000000000000000000000000000000000000000000000000008ca0017507c1dc16935B82698e4C63f2746A2fCf994dF8590dfAec188c567D649ebb4f46e0Df79939D65E0047507c1dc16935B82698e4C63f2746A2fCf994dF800590dfAec188c567D649ebb4f46e0Df79939D65E00192bfc41b2980131386629e67253387cdc5754c04000bb8"
//        });
//
//        IComplexZapper.KodiakDepositParams memory kodiakParams = IComplexZapper.KodiakDepositParams({
//            kodiakVault: 0x0001513F4a1f86da0f02e647609E9E2c630B3a14,
//            amount0Max: 740800307876048127,
//            amount1Max: 21051186108463046933,
//            amount0Min: 737096306336667886,
//            amount1Min: 19498955676192605832,
//            amountSharesMin: 3708840565419767530,
//            receiver: 0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E
//        });
//
//        IComplexZapper.VaultDepositParams memory vaultParams = IComplexZapper.VaultDepositParams({
//            vault: 0x208008F377Ad00ac07A646A1c3eA6b70eB9Fc511,
//            receiver: 0xd00cc2cbF1dA58DC7669f1cA8FFCAc83cDF2C31E,
//            minShares: 370884056541976752999108
//        });
//
//        address inputToken = 0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03;
//
//        try zapper.zapIn(
//            inputToken,
//            params0,
//            params1,
//            kodiakParams,
//            vaultParams
//        ) {
//            console.log("Success!");
//        } catch Error(string memory reason) {
//            console.log("Failed:", reason);
//            revert("Failed");
//        } catch (bytes memory lowLevelData) {
//            console.log("Low level error:");
//            console.logBytes(lowLevelData);
//            revert("Low level error");
//        }
//    }
//}


//contract ZapInTest is Test {
//    address constant SENDER = 0x533ab6191f82a99a46A872608B1373cFd1eE88dE;
//
//    function setUp() public {
//        vm.createSelectFork("https://proportionate-intensive-valley.bera-mainnet.quiknode.pro/d3b81d6689f1824726f1f65ae9570988a3ef8bcb/", 1215069);
//        vm.startPrank(SENDER);
//    }
//
//    function testZapInB() public {
//        // Instance of the contract we're testing
//        IComplexZapper zapper = IComplexZapper(0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc);
//        address inputToken = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;
//
//        // ZapInParams structure for params0
//        IComplexZapper.ZapInParams memory params0 = IComplexZapper.ZapInParams({
//            inputAmount: 274187235487080776,
//            outputQuote: 20093103334936630510,
//            outputMin: 19490310234888531594,
//            executor: 0xa154CCD02848068ceC1c16B3126EBb2BE73553Ed,
//            path: hex"08A38Caa631DE329FF2DAD1656CE789F31AF31420100000000000000000000000000000000000000000000000116d90b067a1d54ee0000000000000000000000000000000000000000000000001c90a093b7d0c200000000000000000000000000000000000000000000000001125291800a74a00001FCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce02eaaa01901C19842E400C6a0c214DC0960F84fcfd4eE3d000a154CCD02848068ceC1c16B3126EBb2BE73553Edffff094Be03f781C497A489E3cB0287833452cA9B9E80B3510cb559f62ab74f624fb8e98443ecc4271ba1c000200000000000000000067ac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6ba154CCD02848068ceC1c16B3126EBb2BE73553Ed01ac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b01ffff094Be03f781C497A489E3cB0287833452cA9B9E80B93977bf046d9b8531a8f78388a85623cc9d08ad0000000000000000000000ab09b6761bf2397Bb5a6624a856cC84A3A14Dcd3fe5a154CCD02848068ceC1c16B3126EBb2BE73553Ed019b6761bf2397Bb5a6624a856cC84A3A14Dcd3fe501ffff018dD1C3e5fB96ca0E45Fe3c3CC521Ad44e12F3e4700a154CCD02848068ceC1c16B3126EBb2BE73553Ed01696969696969696969696969696969696969696902198101cC7b4964dfCa0C16b3b2Cb5BAdA3248FEEc86d2c00a154CCD02848068ceC1c16B3126EBb2BE73553Edffff01f065f7cCf54Ef8596FE77A4836d963d5aF84EB5d00a154CCD02848068ceC1c16B3126EBb2BE73553Ed"
//        });
//
//        // ZapInParams structure for params1
//        IComplexZapper.ZapInParams memory params1 = IComplexZapper.ZapInParams({
//            inputAmount: 725812764512919224,
//            outputQuote: 130345528078352352,
//            outputMin: 126435162236001781,
//            executor: 0xa154CCD02848068ceC1c16B3126EBb2BE73553Ed,
//            path: hex"69696969696969696969696969696969696969690000000000000000000000000000000000000000000000000001cf1491332bbfe000000000000000000000000000000000000000000000000001cd9a3e7d3e2d0000000000000000000000000000000000000000000000000001cef33cba68f6c001FCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce01ffff01901C19842E400C6a0c214DC0960F84fcfd4eE3d000a154CCD02848068ceC1c16B3126EBb2BE73553Ed"
//        });
//
//        // KodiakDepositParams structure
//        IComplexZapper.KodiakDepositParams memory kodiakParams = IComplexZapper.KodiakDepositParams({
//            kodiakVault: 0xEc8BA456b4e009408d0776cdE8B91f8717D13Fa1,
//            amount0Max: 19490310234888531594,
//            amount1Max: 126435162236001781,
//            amount0Min: 18770579543288263198,
//            amount1Min: 124538634802461754,
//            amountSharesMin: 1302081486830130548,
//            receiver: 0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc
//        });
//
//        // VaultDepositParams structure
//        IComplexZapper.VaultDepositParams memory vaultParams = IComplexZapper.VaultDepositParams({
//            vault: 0xD3908dA797eCeC7ea0fBfbacF3118302E215556c,
//            receiver: 0xC725B5484FfCa924CBFcF7120090C73F24a6b0cc,
//            minShares: 130208148683013054799170
//        });
//
//        // Approve the input token if needed
//        IERC20(inputToken).approve(address(zapper), type(uint256).max);
//
//        try zapper.zapIn(
//            inputToken,
//            params0,
//            params1,
//            kodiakParams,
//            vaultParams
//        ) {
//            console.log("Success!");
//        } catch Error(string memory reason) {
//            console.log("Failed:", reason);
//            revert("Failed");
//        } catch (bytes memory lowLevelData) {
//            console.log("Low level error:");
//            console.logBytes(lowLevelData);
//            revert("Low level error");
//        }
//    }
//}


