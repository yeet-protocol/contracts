pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NFTVesting} from "../src/NFTVesting.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockNFTContract} from "./mocks/MockNFTContract.sol";

abstract contract NFTVestingBaseTest {
    NFTVesting public nftVesting;
    MockERC20 public token;
    MockNFTContract public nftContract;

    function setUp() public {
        token = new MockERC20("MockERC20", "MockERC20", 18);
        nftContract = new MockNFTContract();

        nftContract.mint(address(0x1234), 1234);
        nftContract.mint(address(0x1), 1);
        nftContract.mint(address(0x1), 2);

        uint256[] memory blacklistedTokenIds = new uint256[](0);
        uint256[] memory allowedTokenIds = new uint256[](0);

        nftVesting = new NFTVesting(
            token,
            nftContract,
            100_000_000 * 10 ** 18,
            5555,
            block.timestamp,
            30 days * 6,
            blacklistedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), 100_000_000 * 10 ** 18);
    }

    function test() public {}
}

contract NFTVestingVerifyBlacklistCalculations is Test {

    function test_WithoutBlacklist() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        address owner1 = makeAddr("owner1");

        for (uint256 i = 0; i < 100; i++) {
            nftContract.mint(owner1, i);
        }

        uint256[] memory blacklistedTokenIds = new uint256[](0);
        uint256[] memory allowedTokenIds = new uint256[](0);

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            100 ether,
            100,
            block.timestamp,
            30 days * 6,
            blacklistedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), 100 ether);
        assertEq(nftVesting.tokenAmountPerNft(), 1 ether);

        skip(30 days * 6);

        uint256 amountClaimable = nftVesting.claimable(1);
        assertEq(amountClaimable, 1 ether);
    }

    function test_WithBlacklist() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        address owner1 = makeAddr("owner1");

        uint256[] memory blacklistedTokenIds = new uint256[](50);
        uint256[] memory allowedTokenIds = new uint256[](0);

        for (uint256 i = 0; i < 100; i++) {
            nftContract.mint(owner1, i);
        }

        for (uint256 i = 0; i < 50; i++) {
            blacklistedTokenIds[i] = i;
        }

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            100 ether,
            100,
            block.timestamp,
            30 days * 6,
            blacklistedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), 100 ether);
        assertEq(nftVesting.tokenAmountPerNft(), 2 ether);

        skip(30 days * 6);

        uint256 amountClaimable = nftVesting.claimable(99);
        assertEq(amountClaimable, 2 ether);
    }

    function test_RealValuesWithNoBlacklist() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        address owner1 = makeAddr("owner1");

        uint256 collectionSize = 5555;
        uint256 tokenAmount = 150_000_000 ether;

        uint256[] memory blacklistedTokenIds = new uint256[](0);
        uint256[] memory allowedTokenIds = new uint256[](0);

        for (uint256 i = 0; i < collectionSize; i++) {
            nftContract.mint(owner1, i);
        }

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            tokenAmount,
            collectionSize,
            block.timestamp,
            30 days * 3,
            allowedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), tokenAmount);
        assertApproxEqRel(nftVesting.tokenAmountPerNft() * collectionSize, 150_000_000 ether, 1 ether / 100); // 1 peercent diff
    }

    function test_RealValuesWithBlacklist() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        address owner1 = makeAddr("owner1");

        uint256 collectionSize = 5555;
        uint256 blacklistSize = 268;
        uint256 tokenAmount = 150_000_000 ether;
        uint256 tokenAmountMinusBlacklist = 150_000_000 ether - (tokenAmount / collectionSize * blacklistSize);

        uint256[] memory blacklistedTokenIds = new uint256[](blacklistSize);
        uint256[] memory allowedTokenIds = new uint256[](0);

        for (uint256 i = 0; i < collectionSize; i++) {
            nftContract.mint(owner1, i);
        }

        for (uint256 i = 0; i < blacklistSize; i++) {
            blacklistedTokenIds[i] = i;
        }

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            tokenAmountMinusBlacklist,
            collectionSize,
            block.timestamp,
            30 days * 3,
            blacklistedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), tokenAmountMinusBlacklist);
        assertEq(nftVesting.nftAmount(), collectionSize - blacklistSize);
        assertApproxEqRel(nftVesting.tokenAmountPerNft() * nftVesting.nftAmount(), 142_763_276 ether, 1 ether / 100); // 1 peercent diff
    }

    function test_WithAllowList() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        address owner1 = makeAddr("owner1");

        uint256[] memory blacklistedTokenIds = new uint256[](0);
        uint256[] memory allowedTokenIds = new uint256[](10);

        for (uint256 i = 0; i < 100; i++) {
            nftContract.mint(owner1, i);
        }

        for (uint256 i = 0; i < 10; i++) {
            allowedTokenIds[i] = i;
        }

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            100 ether,
            100,
            block.timestamp,
            30 days * 6,
            blacklistedTokenIds,
            allowedTokenIds
        );
        token.mint(address(nftVesting), 100 ether);
        assertEq(nftVesting.tokenAmountPerNft(), 10 ether);

        skip(30 days * 6);

        uint256 amountClaimable = nftVesting.claimable(99);
        assertEq(amountClaimable, 10 ether);
    }
}

contract NFTVestingBlacklist is Test {
    NFTVesting public nftVesting;
    MockERC20 public token;
    MockNFTContract public nftContract;

    address private owner1 = makeAddr("blacklisted address 1");
    address private owner2 = makeAddr("blacklisted address 2");

    function setUp() public {
        token = new MockERC20("MockERC20", "MockERC20", 18);
        nftContract = new MockNFTContract();

        nftContract.mint(owner1, 1234);
        nftContract.mint(owner2, 1);
        nftContract.mint(owner2, 2);

        uint256[] memory blacklistedTokenIds = new uint256[](2);
        blacklistedTokenIds[0] = 1234;
        blacklistedTokenIds[1] = 1;
        uint256[] memory allowedTokenIds = new uint256[](0);

        nftVesting = new NFTVesting(token, nftContract, 100_000_000 * 10 ** 18, 5555, block.timestamp, 30 days * 6, blacklistedTokenIds, allowedTokenIds);
        token.mint(address(nftVesting), 100_000_000 * 10 ** 18);
    }

    function test_addBlacklistedToken() public {
        assertEq(nftVesting.blacklistedTokenIds(1234), true);
        assertEq(nftVesting.blacklistedTokenIds(1), true);
        assertEq(nftVesting.blacklistedTokenIds(2), false);
    }

    function test_canNotMintBlacklistedToken() public {
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(NFTVesting.BlacklistedTokenId.selector, 1234));
        nftVesting.claim(1234);
    }

    function test_canMintNotBlacklistedToken() public {
        skip(1 days);
        vm.prank(owner2);
        nftVesting.claim(2);
    }
}

contract NFTVestingAllowlist is Test {
    NFTVesting public nftVesting;
    MockERC20 public token;
    MockNFTContract public nftContract;

    address private owner1 = makeAddr("allow address 1");
    address private owner2 = makeAddr("allow address 2");
    address private owner3 = makeAddr("normal address 3");

    function setUp() public {
        token = new MockERC20("MockERC20", "MockERC20", 18);
        nftContract = new MockNFTContract();

        nftContract.mint(owner1, 1234);
        nftContract.mint(owner2, 1);
        nftContract.mint(owner3, 2);

        uint256[] memory blacklistedTokenIds = new uint256[](0);
        uint256[] memory allowedTokenIds = new uint256[](2);
        allowedTokenIds[0] = 1234;
        allowedTokenIds[1] = 1;

        nftVesting = new NFTVesting(token, nftContract, 100_000_000 * 10 ** 18, 5555, block.timestamp, 30 days * 6, blacklistedTokenIds, allowedTokenIds);
        token.mint(address(nftVesting), 100_000_000 * 10 ** 18);
    }

    function test_addAllowedToken() public {
        assertEq(nftVesting.allowedTokenIds(1234), true);
        assertEq(nftVesting.allowedTokenIds(1), true);
        assertEq(nftVesting.allowedTokenIds(2), false);
    }

    function test_canMintAllowList() public {
        skip(1 days);
        vm.prank(owner1);
        nftVesting.claim(1234);

        vm.prank(owner2);
        nftVesting.claim(1);
    }

    function test_canNotMintAllowList() public {
        skip(1 days);

        vm.expectRevert(abi.encodeWithSelector(NFTVesting.NotAllowedTokenId.selector, 2));
        vm.prank(owner3);
        nftVesting.claim(2);
    }
}

contract NFTVestingConstructorTest is Test, NFTVestingBaseTest {
    function test_SetsTheConstructorValues() public {
        assertEq(address(nftVesting.token()), address(token));
        assertEq(address(nftVesting.nftContract()), address(nftContract));
        assertEq(nftVesting.tokenAmount(), 100_000_000 * 10 ** 18);
        assertEq(nftVesting.nftAmount(), 5555);
        assertEq(nftVesting.startTime(), block.timestamp);
        assertEq(nftVesting.vestingPeriod(), 30 days * 6);
        assertEq(nftVesting.tokenAmountPerNft(), uint256(100_000_000 * 10 ** 18) / 5555);
    }

    function test_throwsErrorIfBothBlacklistAndAllowList() public {

        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        nftContract.mint(address(0x1234), 1234);
        nftContract.mint(address(0x1), 1);
        nftContract.mint(address(0x1), 2);

        uint256[] memory blacklistedTokenIds = new uint256[](1);
        blacklistedTokenIds[0] = 1234;
        uint256[] memory allowedTokenIds = new uint256[](1);
        allowedTokenIds[0] = 1;

        vm.expectRevert("NFTVesting: can't have both blacklist and allowed list enabled");
        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            100_000_000 * 10 ** 18,
            5555,
            block.timestamp,
            30 days * 6,
            blacklistedTokenIds,
            allowedTokenIds
        );

    }

    function test_TokenAmountPerNft() public {
        MockERC20 token = new MockERC20("MockERC20", "MockERC20", 18);
        MockNFTContract nftContract = new MockNFTContract();

        uint256[] memory blacklistedTokenIds = new uint256[](278);
        for (uint256 i = 0; i < 278; i++) {
            blacklistedTokenIds[i] = i;
        }
        uint256[] memory allowedTokenIds = new uint256[](0);

        NFTVesting nftVesting = new NFTVesting(
            token,
            nftContract,
            139_895_220.919748 ether,  // Total amount minus 1-on-1s (3M)
            5555,                      // Initial NFT supply
            block.timestamp,
            30 days * 3,
            blacklistedTokenIds,
            allowedTokenIds
        );

        assertEq(
            nftVesting.tokenAmountPerNft(),
            26510369702434716695091,
            "Token amount per NFT should be 26,500"
        );
    }
}

contract NFTVestingClaimTest is NFTVestingBaseTest, Test {
    function test_ClaimedIsZero() public {
        vm.startPrank(address(0x1234));
        assertEq(nftVesting.claimed(1234), 0);
    }

    function test_ClaimedIsZeroForOtherAddress() public {
        vm.startPrank(address(0x1234));
        assertEq(nftVesting.claimed(1234), 0);
    }

    function test_ClaimedAllAfterVestingPeriod() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 6);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 18001800180018001800180);
    }

    function test_ClaimedHalfAfterHalfVestingPeriod() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 3);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 9000900090009000900090);
    }

    function test_ClaimTwice() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 3);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 9000900090009000900090);
        skip(30 days * 3);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 18001800180018001800180);
    }

    function test_ClaimAfterVestingPeriod() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 7);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 18001800180018001800180);
    }

    function test_ClaimWillPayoutToOwner() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 6);
        nftVesting.claim(1234);
        assertEq(nftVesting.claimed(1234), 18001800180018001800180);
        assertEq(token.balanceOf(address(0x1234)), 18001800180018001800180);
    }

    function test_ClaimTwiceWillPayoutToOwner() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 3);
        nftVesting.claim(1234);
        assertEq(token.balanceOf(address(0x1234)), 9000900090009000900090);
        skip(30 days * 3);
        nftVesting.claim(1234);
        assertEq(token.balanceOf(address(0x1234)), 18001800180018001800180);
    }

    function test_ClaimWillPayoutToOwnerForOtherAddress() public {
        vm.startPrank(address(0x1234));
        skip(30 days * 6);
        vm.expectRevert("NFTVesting: not the owner of the NFT");
        nftVesting.claim(4567);
    }
}

contract NFTVestingClaimableTest is NFTVestingBaseTest, Test {
    function test_ClaimableIsZero() public {
        assertEq(nftVesting.claimable(1234), 0);
    }

    function test_ClaimableAllAfterVestingPeriod() public {
        skip(30 days * 6);
        assertEq(nftVesting.claimable(1234), 18001800180018001800180);
    }

    function test_ClaimableHalfAfterHalfVestingPeriod() public {
        skip(30 days * 3);
        assertEq(nftVesting.claimable(1234), 9000900090009000900090);
    }

    function test_ClaimableTwice() public {
        skip(30 days * 3);
        assertEq(nftVesting.claimable(1234), 9000900090009000900090);
        skip(30 days * 3);
        assertEq(nftVesting.claimable(1234), 18001800180018001800180);
    }

    function test_ClaimableMany() public {
        vm.startPrank(address(0x1));

        skip(30 days * 3);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        assertEq(nftVesting.claimableMany(tokenIds), 18001800180018001800180);

        nftVesting.claimMany(tokenIds);
        assertEq(nftVesting.claimed(1), 9000900090009000900090);
        assertEq(nftVesting.claimed(2), 9000900090009000900090);

        skip(30 days * 3);
        assertEq(nftVesting.claimableMany(tokenIds), 18001800180018001800180);
    }
}
