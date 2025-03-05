// SPDX
pragma solidity ^0.8.20;

// imports
import {ICommunalFarm} from "../src/interfaces/kodiak/ICommunalFarm.sol";
import {IKodiakV1RouterStaking} from "../src/interfaces/kodiak/IKodiakV1RouterStaking.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {IMoneyBrinter} from "../src/interfaces/IMoneyBrinter.sol";
import {IZapper} from "../src/interfaces/IZapper.sol";
import {IKodiakVaultV1} from "../src/interfaces/kodiak/IKodiakVaultV1.sol";
import "../src/interfaces/beradrome/IPlugin.sol";
import "../src/interfaces/beradrome/IGauge.sol";
import "../src/interfaces/kodiak/IKodiakRewards.sol";
import "../src/interfaces/kodiak/IXKdkTokenUsage.sol";
import "../src/interfaces/kodiak/IXKdkToken.sol";
import "../src/interfaces/oogabooga/IOBRouter.sol";

import "../src/contracts/MoneyBrinter.sol";
import "../src/contracts/Zapper.sol";

// libraries
import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

struct Contracts {
    IMoneyBrinter moneyBrinter;
    IZapper zapper;
    IKodiakV1RouterStaking kodiakStakingRouter;
    IKodiakVaultV1 yeetIsland;
    IPlugin beradromeFarmPlugin;
    IGauge beradromeFarmRewardsGauge;
    IOBRouter obRouter;
    ICommunalFarm kodiakFarm;
    IKodiakRewards kodiakRewards;
}

abstract contract ForkTest is Test {
    // fork addresses

    // swap router
    address public obRouter = 0x7bC98B68bCBb16cEC81EdDcEa1A3746Fdc5025A4;

    // kodiak addresses
    address public KodiakRouterStakingV1 = 0x4d41822c1804ffF5c038E4905cfd1044121e0E85;
    address public kodiakRewards = 0x0176a52d7F631Db0759cB52d444226f86D57165d;
    address public kodiakFarm = 0xbdEE3F788a5efDdA1FcFe6bfe7DbbDa5690179e6;
    address public kdk = 0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364;
    address public xKdk = 0x414B50157a5697F14e91417C5275A7496DcF429D;
    address public yeetIsland = 0xE5A2ab5D2fb268E5fF43A5564e44c3309609aFF9;

    // Tokens
    address public Wbera = 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8;
    address public Weth = 0xE28AfD8c634946833e89ee3F122C06d7C537E8A8;
    address public honey = 0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03;
    address public yeet = 0x1740F679325ef3686B2f574e392007A92e4BeD41;

    address public yeetWhale = 0x9a19c70e83cc714987ff36E3F831968e6A31D00A;
    address public WberaWhale = 0xAB827b1Cc3535A9e549EE387A6E9C3F02F481B49;
    address public honeyWhale = 0x1F5c5b2AA38E4469a6Eb09f8EcCa5D487E9d1431;
    address public assetWhale = 0xbdEE3F788a5efDdA1FcFe6bfe7DbbDa5690179e6;
    // beradrome addresses
    address public oBero = 0x7629668774f918c00Eb4b03AdF5C4e2E53d45f0b;
    address public beradromeFarmPlugin = 0x80D7759Fa55f6a1F661D5FCBB3bC5164Dc63eb4D;
    address public beradromeFarmRewardsGauge = 0x981E491Dd159F17009CF7cd27a98eAB995c2fa6C;

    // deployed addresses
    address public moneyBrinter;
    address public zapper;

    // addresses and users
    address public owner;
    address public admin;
    address public treasury;
    address public alice;
    address public bob;
    address public charlie;
    address public strategyManager;
    uint256 public ownerKey;
    uint256 public adminKey;
    uint256 public treasuryKey;
    uint256 public aliceKey;
    uint256 public bobKey;
    uint256 public charlieKey;

    uint256 tickLength = 60 * 60; // 1 hour
    uint256 withdrawalPeriod = 4 * 60 * 60; // 4 hours
    uint256 rateLimitCooldownPeriod = 60 * 60; // 4 hours

    Contracts contracts;

    string constant rpc_url = "https://bartio.rpc.berachain.com/";

    function initializeContracts(uint256 blockNumber) public {
        uint256 forkId;
        if (blockNumber == 0) {
            forkId = vm.createFork(rpc_url);
        } else {
            forkId = vm.createFork(rpc_url, blockNumber);
        }
        vm.selectFork(forkId);

        // fork vm at block number
        (alice, aliceKey) = makeAddrAndKey("alice");
        (bob, bobKey) = makeAddrAndKey("bob");
        (charlie, charlieKey) = makeAddrAndKey("charlie");
        (admin, adminKey) = makeAddrAndKey("admin");
        (owner, ownerKey) = makeAddrAndKey("owner");
        (treasury, treasuryKey) = makeAddrAndKey("treasury");
        (strategyManager,) = makeAddrAndKey("strategyManager");

        // fund addresses with native
        vm.deal(owner, 100_000 ether);
        vm.deal(alice, 100_000 ether);
        vm.deal(bob, 100_000 ether);
        vm.deal(charlie, 100_000 ether);
        vm.deal(admin, 100_000 ether);
        vm.deal(owner, 100_000 ether);
        vm.deal(treasury, 100_000 ether);

        vm.startPrank(admin);

        contracts.moneyBrinter = new MoneyBrinter(
            yeetIsland, "MoneyBrinter", "MBRR", treasury, beradromeFarmPlugin, beradromeFarmRewardsGauge, 2000
        );
        moneyBrinter = address(contracts.moneyBrinter);

        address[] memory protectedContracts = new address[](1);
        protectedContracts[0] = address(contracts.moneyBrinter);
        contracts.moneyBrinter.setStrategyManager(strategyManager, true);
        contracts.moneyBrinter.setKodiakRewards(kodiakRewards);
        contracts.moneyBrinter.setXKdk(xKdk);
        contracts.moneyBrinter.setTreasury(treasury);
        // contracts.moneyBrinter.setAllocationFlagxKDK(true);

        contracts.zapper = new Zapper(obRouter, KodiakRouterStakingV1, Wbera);
        zapper = address(contracts.zapper);
        contracts.moneyBrinter.setZapper(zapper);
        contracts.zapper.updateSwappableTokens(honey, true);
        contracts.zapper.updateSwappableTokens(oBero, true);
        contracts.zapper.updateSwappableTokens(kdk, true);
        contracts.zapper.updateWhitelistedKodiakVault(yeetIsland, true);
        contracts.zapper.setCompoundingVault(moneyBrinter, true);
        vm.stopPrank();
        contracts.kodiakStakingRouter = IKodiakV1RouterStaking(KodiakRouterStakingV1);
        contracts.yeetIsland = IKodiakVaultV1(yeetIsland);
        contracts.beradromeFarmPlugin = IPlugin(beradromeFarmPlugin);
        contracts.beradromeFarmRewardsGauge = IGauge(beradromeFarmRewardsGauge);
        contracts.obRouter = IOBRouter(obRouter);
        contracts.kodiakFarm = ICommunalFarm(kodiakFarm);
        contracts.kodiakRewards = IKodiakRewards(kodiakRewards);
    }

    function fundToken(address user, address token, uint256 amount) public {
        if (token == Wbera) {
            fundWbera(user, amount);
        } else if (token == yeet) {
            fundYeet(user, amount);
        } else if (token == honey) {
            fundHoney(user, amount);
        }
    }

    function fundWbera(address user, uint256 amount) public {
        vm.deal(user, amount);
        vm.prank(user);
        IWETH(Wbera).deposit{value: amount}();
    }

    function fundYeet(address user, uint256 amount) public {
        vm.prank(yeetWhale);
        IERC20(yeet).transfer(user, amount);
    }

    function fundHoney(address user, uint256 amount) public {
        vm.prank(honeyWhale);
        IERC20(honey).transfer(user, amount);
    }

    function increaseAsset(address user, uint256 amount) internal {
        if (amount == 0) return;
        vm.prank(assetWhale);
        IERC20(yeetIsland).transfer(user, amount);
    }

    function decreaseAsset(address user, uint256 amount) internal {
        if (amount == 0) return;
        vm.prank(user);
        IERC20(yeetIsland).transfer(assetWhale, amount);
    }

    function increaseTimeAndBlock(uint256 time, uint256 blocks) public {
        vm.warp(block.timestamp + time);
        vm.roll(block.number + blocks);
    }
}
