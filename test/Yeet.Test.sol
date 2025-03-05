import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Yeet.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockWBERA.sol";
import "../src/Reward.sol";
import "../src/RewardSettings.sol";
import "../src/YeetGameSettings.sol";
import "../src/INFTContract.sol";
import "./mocks/MockNFTContract.sol";
import "./MockEntropy.sol";
import "../src/interfaces/IZapper.sol";

abstract contract YeetBaseTest {
    Yeet public yeet;
    MockNFTContract public nft;
    Reward public reward;
    YeetGameSettings public gameSettings;

    function setUp() public virtual {
        YeetToken token = new YeetToken();
        RewardSettings settings = new RewardSettings();
        reward = new Reward(token, settings);
        IZapper zapper = IZapper(address(0x0000a));
        StakeV2 staking = new StakeV2(token, zapper, address(this), address(this), IWETH(address(0x0000b)));
        YeetGameSettings gameSettings = new YeetGameSettings();
        nft = new MockNFTContract();
        MockEntropy entropy = new MockEntropy();

        yeet = new Yeet(
            address(token),
            reward,
            staking,
            gameSettings,
            address(0x0e),
            address(0x0c),
            address(0x0),
            address(entropy),
            address(0x0001)
        );
        yeet.setYeetardsNFTsAddress(address(nft));
    }
}


contract Yeet_ForkTestTaxes is Test {

      function setUp() public {
        vm.createSelectFork("https://proportionate-intensive-valley.bera-mainnet.quiknode.pro/d3b81d6689f1824726f1f65ae9570988a3ef8bcb/", 1744652);
    }

    function test_ForkCorrectTax() public {
        skip(1 hours);

        Yeet yeet = Yeet(payable(0xEe6f49Dc2f1D0d9567dDd3FD6D77D8F7edfe7379));
        uint value = yeet.yeetback().getEntropyFee();
        yeet.restart{
            value: value
            }(0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d);

        (uint256 valueToPot, uint256 valueToYeetBack, uint256 valueToStakers, uint256 publicGoods, uint256 teamRevenue)
        = yeet.getDistribution(1 ether);
        assertEq(valueToPot, 0.65 ether);
        assertEq(valueToYeetBack, 0.2 ether);
        assertEq(valueToStakers, 0.09 ether);
        assertEq(publicGoods, 0.0099 ether);
        assertEq(teamRevenue, 0.0501 ether);
    }

}

contract Yeet_TestTaxes is Test {
    Yeet public yeet;
    MockNFTContract public nft;
    Reward public reward;
    YeetGameSettings public gameSettings;

    function setUp() public virtual {
        YeetToken token = new YeetToken();
        RewardSettings settings = new RewardSettings();
        reward = new Reward(token, settings);
        IZapper zapper = IZapper(address(0x0000a));
        StakeV2 staking = new StakeV2(token, zapper, address(this), address(this), IWETH(address(0x0000b)));
        YeetGameSettings gameSettings = new YeetGameSettings();

        gameSettings.setYeetSettings(
            3600,
            200,
            1500,
            6000,
            660,
            3340,
            2000,
            0,
            0,
            0.001 ether
        );

        nft = new MockNFTContract();
        MockEntropy entropy = new MockEntropy();

        yeet = new Yeet(
            address(token),
            reward,
            staking,
            gameSettings,
            address(0x0e),
            address(0x0c),
            address(0x0),
            address(entropy),
            address(0x0001)
        );

        yeet.setYeetardsNFTsAddress(address(nft));
    }

    function test_CorrectTax() public {

        (uint256 valueToPot, uint256 valueToYeetBack, uint256 valueToStakers, uint256 publicGoods, uint256 teamRevenue)
        = yeet.getDistribution(1 ether);
        assertEq(valueToPot, 0.65 ether);
        assertEq(valueToYeetBack, 0.2 ether);
        assertEq(valueToStakers, 0.09 ether);
        assertEq(publicGoods, 0.0099 ether);
        assertEq(teamRevenue, 0.0501 ether);
    }

}

contract Yeet_BootstrapPhase is Test {
    Yeet public yeet;
    MockNFTContract public nft;
    Reward public reward;
    YeetGameSettings public gameSettings;

    function setUp() public virtual {
        YeetToken token = new YeetToken();
        RewardSettings settings = new RewardSettings();
        reward = new Reward(token, settings);
        IZapper zapper = IZapper(address(0x0000a));
        StakeV2 staking = new StakeV2(token, zapper, address(this), address(this), IWETH(address(0x0000b)));
        YeetGameSettings gameSettings = new YeetGameSettings();
        gameSettings.setYeetSettings(
            gameSettings.YEET_TIME_SECONDS(),
            gameSettings.POT_DIVISION(),
            gameSettings.TAX_PER_YEET(),
            gameSettings.TAX_TO_STAKERS(),
            gameSettings.TAX_TO_PUBLIC_GOODS(),
            gameSettings.TAX_TO_TREASURY(),
            gameSettings.YEETBACK_PERCENTAGE(),
            gameSettings.COOLDOWN_TIME(),
            1 days,
            gameSettings.MINIMUM_YEET_POINT()
        );
        nft = new MockNFTContract();
        MockEntropy entropy = new MockEntropy();

        yeet = new Yeet(
            address(token),
            reward,
            staking,
            gameSettings,
            address(0x0a),
            address(0x0c),
            address(0x0),
            address(entropy),
            address(0x0001)
        );
        yeet.setYeetardsNFTsAddress(address(nft));
        reward.setYeetContract(address(yeet));
    }

    function test_yeetDoesNotIncreaseMinYeetPoint() public {
        assertTrue(yeet.isBoostrapPhase());
        assertEq(yeet.minimumYeetPoint(), 0.001 ether);
        yeet.yeet{value: 1 ether}();
        assertEq(yeet.minimumYeetPoint(), 0.001 ether);
    }

    function test_yeetDoesIncreaseMinYeetPointWhenPhaseEnds() public {
        assertTrue(yeet.isBoostrapPhase());
        yeet.yeet{value: 1 ether}();
        assertEq(yeet.minimumYeetPoint(), 0.001 ether);
        vm.warp(1 days + 1);
        assertFalse(yeet.isBoostrapPhase());
        assertEq(yeet.minimumYeetPoint(), 0.0035 ether);
    }

    function test_yeetDuringBootstrapPhase() public {
        assertTrue(yeet.isBoostrapPhase());
        vm.expectCall(
            address(yeet.yeetback()), abi.encodeWithSelector(Yeetback.addYeetsInRound.selector, 1, address(this)), 1000
        );

        yeet.yeet{value: 1 ether}();
    }

    function test_endOfYeetTimeShouldBeTheSameForTheDurationOfTheBootstrapPhase() public {
        assertTrue(yeet.isBoostrapPhase());
        uint256 endtime = yeet.endOfYeetTime();
        vm.warp(12 hours);
        yeet.yeet{value: 1 ether}();
        uint256 endtime2 = yeet.endOfYeetTime();
        assertEq(endtime, endtime2);
    }

    function test_endTimeShoulUpdateWhenPhaseEnds() public {
        assertTrue(yeet.isBoostrapPhase());
        vm.warp(1 days + 30 minutes);
        assertFalse(yeet.isBoostrapPhase());
        yeet.yeet{value: 0.001 ether}();
        assertEq(yeet.endOfYeetTime(), block.timestamp + yeet.yeetTimeInSeconds());
    }

    function test_restartShouldSetCorrectEndTime() public {
        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        yeet.yeet{value: 0.001 ether}();
        vm.warp(1 days + 2 hours);
        assertFalse(yeet.isBoostrapPhase());
        yeet.restart{value: 1 ether}(randomNumber);
        assertEq(yeet.endOfYeetTime(), block.timestamp + yeet.yeetTimeInSeconds() + yeet.BOOSTRAP_PHASE_DURATION());
    }

    fallback() external payable {}
}

contract Yeet_PublicGoods is Test, YeetBaseTest {
    function setUp() public override {
        super.setUp();
        reward.setYeetContract(address(yeet));
        yeet.yeet{value: 1 ether}();
    }

    function test_PublicGoodsTax() public {
        assertEq(yeet.publicGoodsAmount(), 0.01 ether);
    }

    function test_CanUpdatePublicGoodsAddress() public {
        assertEq(yeet.publicGoodsAddress(), address(0x0e));
        yeet.setPublicGoodsAddress(address(0x0c));
        assertEq(yeet.publicGoodsAddress(), address(0x0c));
    }

    function test_PayoutPublicGoods() public {
        assertEq(address(0x0e).balance, 0.0 ether);
        yeet.payoutPublicGoods();
        assertEq(address(0x0e).balance, 0.01 ether);
    }
}

contract Yeet_TeamRevenue is Test, YeetBaseTest {
    function setUp() public override {
        super.setUp();
        reward.setYeetContract(address(yeet));
        yeet.yeet{value: 1 ether}();
    }

    function test_TeamTax() public {
        assertEq(yeet.treasuryRevenueAmount(), 0.02 ether);
    }

    function test_CanUpdateTeamAddress() public {
        assertEq(yeet.treasuryRevenueAddress(), address(0x0c));
        yeet.setTreasuryRevenueAddress(address(0x0d));
        assertEq(yeet.treasuryRevenueAddress(), address(0x0d));
    }

    function test_PayoutTeamRevenue() public {
        assertEq(address(0x0c).balance, 0.0 ether);
        yeet.payoutTreasuryRevenue();
        assertEq(address(0x0c).balance, 0.02 ether);
    }
}

contract Yeet_getDistribution is Test, YeetBaseTest {
    function test_getDistribution() public {
        (uint256 valueToPot, uint256 valueToYeetBack, uint256 valueToStakers, uint256 publicGoods, uint256 teamRevenue)
        = yeet.getDistribution(1 ether);
        assertEq(valueToPot, 0.7 ether);
        assertEq(valueToYeetBack, 0.2 ether);
        assertEq(valueToStakers, 0.07 ether);
        assertEq(publicGoods, 0.01 ether);
        assertEq(teamRevenue, 0.02 ether);
    }
}

contract Yeet_NFTBoost_WorksWhenContractIsEmpty is Test, YeetBaseTest {
    function test_NFTBoostWhenAddressIsNull() public {
        assertEq(yeet.getNFTBoost(address(0x1), new uint256[](0)), 0);
    }
}

contract Yeet_Yeetback is Test, YeetBaseTest {
    function setUp() public override {
        super.setUp();
        reward.setYeetContract(address(yeet));
        yeet.yeet{value: 1 ether}();
    }

    function test_addYeetbackToMuchFee() public {
        skip(2 hours);
        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint256 balanceBefore = address(this).balance;
        uint128 fee = yeet.yeetback().getEntropyFee();

        yeet.restart{value: fee + 1 ether}(randomNumber);

        uint256 balanceAfter = address(this).balance;

        assertApproxEqAbs(balanceAfter, balanceBefore - fee, 1 wei);
    }

    function test_AddYeetbackRevertsIfFeeIsNotPaid() public {
        skip(2 hours);
        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint256 balanceBefore = address(this).balance;
        uint128 fee = yeet.yeetback().getEntropyFee();

        vm.expectRevert(abi.encodeWithSelector(Yeet.NotEnoughValueToPayEntropyFee.selector, 0, fee));

        yeet.restart{value: 0}(randomNumber);
    }

    receive() external payable {}
}

contract Yeet_MinYeetAmount is Test, YeetBaseTest {
    function setUp() public override {
        super.setUp();
        reward.setYeetContract(address(yeet));
    }

    function test_MinYeetAmountIsCorrect() public {
        assertEq(yeet.minimumYeetPoint(), 0.001 ether);

        yeet.yeet{value: 0.001 ether}();

        vm.expectRevert(abi.encodeWithSelector(Yeet.InsufficientYeet.selector, 0.0009 ether, 0.001 ether));
        yeet.yeet{value: 0.0009 ether}();
    }
}

contract Yeet_Claim is Test, YeetBaseTest {
    function setUp() public override {
        super.setUp();
        reward.setYeetContract(address(yeet));
    }

    function test_claimEmitCorrectEvent() public {
        yeet.yeet{value: 1 ether}();

        skip(2 hours);
        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint128 fee = yeet.yeetback().getEntropyFee();

        console2.log("address", address(this));
        console2.log("yeet address", address(yeet));
        vm.expectEmit();
        emit Yeet.RoundWinner(address(this), block.timestamp, 0.7 ether, 1, yeet.nrOfYeets());
        yeet.restart{value: fee}(randomNumber);

        vm.expectEmit();
        emit Yeet.Claim(address(this), block.timestamp, 0.7 ether);
        yeet.claim();
    }

    function test_claimEmitCorrectEventsComplicated() public {
        address lastYeeted = address(0x0);
        for (uint256 i = 0; i < 100; i++) {
            address randomAddress = address(bytes20(keccak256(abi.encode(i))));
            payable(randomAddress).send(1 ether);

            vm.startPrank(randomAddress);
            yeet.yeet{value: 1 ether}();
            vm.stopPrank();

            skip(30 minutes);
            lastYeeted = randomAddress;
        }

        skip(2 hours);
        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint128 fee = yeet.yeetback().getEntropyFee();

        vm.expectEmit();
        emit Yeet.RoundWinner(lastYeeted, block.timestamp, 70 ether, 1, yeet.nrOfYeets());
        yeet.restart{value: fee}(randomNumber);

        vm.expectEmit();
        emit Yeet.Claim(lastYeeted, block.timestamp, 70 ether);
        vm.startPrank(lastYeeted);
        yeet.claim();
        vm.stopPrank();
    }

    receive() external payable {}
}

contract Yeet_NFTBoost is Test, YeetBaseTest {
    function test_NFTBoost_SameIds() public {
        nft.mintAmount(address(0x1), 1);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        vm.expectRevert(abi.encodeWithSelector(Yeet.DuplicateTokenId.selector, 1));
        yeet.yeet(ids);
    }

    function test_NFTBoost_ToManyIds() public {
        nft.mintAmount(address(0x1), 1);
        uint256[] memory ids = new uint256[](27);
        for (uint256 i = 0; i < ids.length; i++) {
            ids[i] = 1;
        }

        vm.expectRevert(abi.encodeWithSelector(Yeet.ToManyTokenIds.selector, 27));
        yeet.yeet(ids);
    }

    //
    //    function test_NFTBoost_0() public {
    //        assertEq(yeet.getNFTBoost(address(0x1)), 0);
    //    }
    //
    //    function test_NFTBoost_1() public {
    //        nft.mintAmount(address(0xa), 1);
    //        assertEq(yeet.getNFTBoost(address(0xa)), 345);
    //    }
    //
    //    function test_NFTBoost_2() public {
    //        nft.mintAmount(address(0xb), 2);
    //        assertEq(yeet.getNFTBoost(address(0xb)), 540);
    //    }
    //
    //    function test_NFTBoost_25() public {
    //        nft.mintAmount(address(0xb), 25);
    //        assertEq(yeet.getNFTBoost(address(0xb)), 1500);
    //    }
    //
    //    function test_NFTBoost_26() public {
    //        nft.mintAmount(address(0xb), 26);
    //        assertEq(yeet.getNFTBoost(address(0xb)), 1500);
    //    }
    //
    //    function test_GetValueBoostedMax() public {
    //        nft.mintAmount(address(0xc), 50);
    //        assertEq(yeet.getBoostedValue(address(0xc), 1000), 1150);
    //    }
    //
    //    function test_GetValueBoosted0() public {
    //        assertEq(yeet.getBoostedValue(address(0xd), 1000), 1000);
    //    }
    //
    //    function test_GetValueBoosted1() public {
    //        nft.mintAmount(address(0xd), 1);
    //        assertEq(yeet.getBoostedValue(address(0xd), 1000 * 10 ** 18), 1034.5 * 10 ** 18);
    //    }
}

//contract Yeet_NFTBoostSettingYeetardsNFTAfterDeployment is Test, YeetBaseTest {
//
//    function test_NFTBoost_1() public {
//        nft.mintAmount(address(0xa), 1);
//        assertEq(yeet.getNFTBoost(address(0xa)), 345);
//    }
//
//}
