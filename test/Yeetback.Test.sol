pragma solidity ^0.8.19;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Yeetback.sol";
import "./MockEntropy.sol";

contract YeetbackTest is Test {
    Yeetback private yeetback;
    MockEntropy private entropy;

    function setUp() public {
        entropy = new MockEntropy();

        yeetback = new Yeetback(address(entropy), address(0x0b));
    }

    function test_AddYeetsInRound() public {
        yeetback.addYeetsInRound(1, address(0x1));
        yeetback.addYeetsInRound(1, address(0x2));
        yeetback.addYeetsInRound(1, address(0x3));

        assertEq(yeetback.getYeetsInRound(1).length, 3);
    }

    function test_addYeetback() public {
        for (uint256 i = 0; i < 1000; i++) {
            address yeetbackAddress = address(bytes20(keccak256(abi.encode(i))));
            yeetback.addYeetsInRound(1, yeetbackAddress);
        }

        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint128 fee = yeetback.getEntropyFee();
        yeetback.addYeetback{value: fee}(randomNumber, 1, 10 ether);

        assertEq(yeetback.potForRound(1), 10 ether);
        assertEq(yeetback.sequenceToRound(654321), 1);
        assertEq(yeetback.finishedSequenceNumbers(654321), false);
    }

    function test_draftWinner() public {
        for (uint256 i = 0; i < 1000; i++) {
            address yeetbackAddress = address(bytes20(keccak256(abi.encode(i))));
            yeetback.addYeetsInRound(1, yeetbackAddress);
        }

        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint128 fee = yeetback.getEntropyFee();
        yeetback.addYeetback{value: fee}(randomNumber, 1, 10 ether);

        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xA4603bd68Fc422e1dc55216f094642f0691E8c28), 1 ether, 930);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xacB5979866E9696cc835D348aeB81CDbf3526390), 1 ether,589);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xF153EB7cC74CCDCE642D2b4E703de096ED90E6fD), 1 ether,936);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xF0f854bf360510BB2726d18A597904D08A91e977), 1 ether,663);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xb9B3944c1e7334a635685c15B1ec0e8F5F548b43), 1 ether,996);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xC3fc131ce07117eAe6cB5734885994e551AF77dE), 1 ether,827);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0x38395C5dceade9603479B177b68959049485dF8A), 1 ether,56);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0x405787FA12A823e0F2b7631cc41B3bA8828b3321), 1 ether,2);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0x393A60fC9175593E1a78E765b331DE118c5f3515), 1 ether,415);
        vm.expectEmit();
        emit Yeetback.YeetbackWinner(1, address(0xcFc479828D8133d824A47fE26326d458b6B94134), 1 ether,198);

        vm.startPrank(address(entropy));
        yeetback._entropyCallback(
            654321, address(0x0b), 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d
        );
        assertEq(yeetback.finishedSequenceNumbers(654321), true);
    }

    function test_draftSameWinnerMultipleTimes() public {
        yeetback.addYeetsInRound(1, address(0x1));

        bytes32 randomNumber = 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d;

        uint128 fee = yeetback.getEntropyFee();
        yeetback.addYeetback{value: fee + 10 ether}(randomNumber, 1, 10 ether);

        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit();
            emit Yeetback.YeetbackWinner(1, address(0x1), 1 ether,0); // We start at 0, so the first yeet is at index 0
        }

        vm.startPrank(address(entropy));
        yeetback._entropyCallback(
            654321, address(0x0b), 0x3b67d060cb9b8abcf5d29e15600b152af66a881e8867446e798f5752845be90d
        );
        vm.stopPrank();

        assertEq(yeetback.claimable(1, address(0x1)), 10 ether);

        vm.startPrank(address(0x1));
        yeetback.claim(1);
        vm.stopPrank();

        assertEq(yeetback.claimable(1, address(0x1)), 0 ether);
    }
}
