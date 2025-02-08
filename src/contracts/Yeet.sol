// SPDX-License-Identifier: AGPL-3.0-or-later
/*
 * Copyright (C) 2024 Squangleding Corporation
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * Full license text is available at:
 * https://github.com/yeet-protocol/contracts/blob/main/LICENSE.md
 */
pragma solidity ^0.8.19;

import "./Reward.sol";
import "./YeetToken.sol";
import "./YeetGameSettings.sol";
import "./INFTContract.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Yeetback.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../lib/forge-std/src/console2.sol";
import {StakeV2} from "./StakeV2.sol";

/// @title Core game logic for Yeet
/// @notice The game works by having users yeet in a pot, the last user to yeet before the yeet time ends wins the pot
/// @notice The timer that decides when the yeet time ends is reset every time a user yeets
/// @notice User can get a multiplier on their yeet by owning NFTs
/// @notice The pot is divided into a winner pot and a yeetback pot
/// @notice The Yeetback pot is paid out to random users that yeeted in the round
contract Yeet is Pausable, Ownable, ReentrancyGuard {
    // Errors
    /// @dev InsufficientYeet is when a user tries to yeet less than the minimum yeet point
    error InsufficientYeet(uint256 provided, uint256 minimum);
    /// @dev YeetTimePassed is when a user tries to yeet after the yeet time has passed
    error YeetTimePassed(uint256 currentTime, uint256 endTime);
    /// @dev RoundStillLive is when a user tries to restart the game while the round is still live
    error RoundStillLive(uint256 roundNumber);
    /// @dev NoWinningsToClaim is when a user tries to claim winnings but has none
    error NoWinningsToClaim(address user);
    /// @dev InvalidRandomNumber is when a user tries to restart the game without a random number
    error InvalidRandomNumber();
    /// @dev CooldownNotEnded is when a user tries to restart the game before the cooldown has ended
    error CooldownNotEnded(uint256 currentTime, uint256 cooldownEndTime);
    /// @dev NotEnoughValueToPayEntropyFee is when a user tries to restart the game without paying the entropy fee
    error NotEnoughValueToPayEntropyFee(uint256 value, uint256 fee);
    /// @dev UserDoesNotOwnNFTs is when a user tries to get a boost from NFTs they do not own
    error UserDoesNotOwnNFTs(address user, uint256 tokenId);
    /// @dev NFTNotEligibleForBoost is when a user tries to get a boost from an NFT that is not eligible
    error NFTNotEligibleForBoost(uint256 tokenId);
    /// @dev ToManyTokenIds is when a user tries to yeet with too many tokenIds
    error ToManyTokenIds(uint256 length);
    /// @dev DuplicateTokenId is when a user tries to yeet with duplicate tokenIds
    error DuplicateTokenId(uint256 tokenId);

    // State variables
    /// @dev _lastYeeted is the last user to yeet before the yeet time ends
    address public lastYeeted;
    /// @dev _lastYeetedAt is the timestamp of the last yeet in the round
    uint256 public lastYeetedAt;
    /// @dev _potToWinner is the pot that goes to the winner
    uint256 public potToWinner;
    /// @dev _potToYeetback is the pot that goes to the yeetback
    uint256 public potToYeetback;
    /// @dev _nrOfYeets is the number of yeets in the round
    uint256 public nrOfYeets;
    /// @dev _yeetTimeInSeconds is the time between yeets
    uint256 public yeetTimeInSeconds;
    /// @dev _endOfYeetTime is the timestamp when the yeet time ends, it adds _yeetTimeInSeconds to the current block timestamp
    uint256 public endOfYeetTime;
    /// @notice roundNumber is the current round number
    uint256 public roundNumber = 1;
    /// @notice _roundStartTime is the timestamp when the round started
    uint256 public roundStartTime;

    // Vault
    /// @notice publicGoodsAmount is the amount of public goods tax that has been collected
    uint256 public publicGoodsAmount;
    /// @notice publicGoodsAddress is the address that the public goods tax is sent to
    address public publicGoodsAddress;
    /// @notice treasuryRevenueAddress is the address that the treasury revenue tax is sent to
    address public treasuryRevenueAddress;
    /// @notice treasuryRevenueAmount is the amount of treasury revenue tax that has been collected
    uint256 public treasuryRevenueAmount;

    // Settings from YeetGameSettings
    /// @notice see `YeetGameSettings` for more information
    uint256 public YEET_TIME_SECONDS; // The time between yeets
    uint256 public POT_DIVISION; // 1/xth of the pot eg, x%, 1/200 = 0.5%
    uint256 public TAX_PER_YEET; // The tax per yeet in %
    uint256 public TAX_TO_STAKERS; // The tax to stakers in %
    uint256 public TAX_TO_PUBLIC_GOODS; // The tax to public goods in %
    uint256 public TAX_TO_TREASURY; // The tax to treasury in %
    uint256 public YEETBACK_PERCENTAGE; // The percentage of the pot that goes to yeetback
    uint256 public COOLDOWN_TIME; // The time between rounds
    uint256 public BOOSTRAP_PHASE_DURATION; // The time between rounds
    uint256 public MINIMUM_YEET_POINT; // The minimum amount needed to yeet

    // Contracts
    /// @notice yeetTokenAddress is the address of the YeetToken contract
    address public yeetTokenAddress;
    /// @notice rewardsContract is the Reward contract
    Reward public rewardsContract;
    /// @notice stakingContract is the StakeV2 contract
    StakeV2 public stakingContract;
    /// @notice gameSettings is the YeetGameSettings contract
    YeetGameSettings public gameSettings;
    /// @notice yeetardsNFTsAddress is the address of the NFT contract
    address public yeetardsNFTsAddress;
    /// @notice yeetback is the Yeetback contract
    Yeetback public yeetback;

    // Events
    event Yeet(
        address indexed user,
        uint256 timestamp,
        uint256 basisPointTaxed,
        uint256 amountToPot,
        uint256 amountToYeetback,
        uint256 potAfterYeet,
        uint256 yeetbackAfterYeet,
        uint256 newYeetTimeInSeconds,
        uint256 newMinimumYeetPoint,
        uint256 nrOfYeets,
        uint256 round,
        uint256 timeLeftOnTimer
    );
    event YeetDistribution(
        uint256 totalAmountYeeted,
        uint256 valueToPot,
        uint256 valueToYeetback,
        uint256 valueToStakers,
        uint256 publicGoods,
        uint256 teamRevenue
    );
    event Yeetard(
        address indexed user, uint256 timestamp, uint256 potToWinnerAfter, uint256 newMinimumYeetPoint, uint256 round
    );
    event Claim(address indexed user, uint256 timestamp, uint256 value);
    event RoundWinner(address indexed user, uint256 timestamp, uint256 amount, uint256 round, uint256 nrOfYeets);
    event PublicGoodsPaidOut(address indexed add, uint256 timestamp, uint256 amount);
    event TreasuryRevenuePaidOut(address indexed add, uint256 timestamp, uint256 amount);
    event UpdatedPublicGoodsAddress(address indexed add);
    event UpdatedTreasuryRevenueAddress(address indexed add);
    event UpdatedYeetardsNFTsAddress(address indexed add);
    event RoundStarted(
        uint256 indexed round,
        uint256 startTime,
        uint256 yeetTimeInSeconds,
        uint256 potDivision,
        uint256 taxPerYeet,
        uint256 taxToStakers,
        uint256 taxToPublicGoods,
        uint256 taxToTreasury,
        uint256 yeetbackPercentage,
        uint256 cooldownTime
    );

    // Structs
    struct Winner {
        address user;
        uint256 timestamp;
        uint256 amount;
        uint256 round;
    }

    /// @notice _roundWinners is a mapping of round number to the winner of that round
    /// @dev roundNumber => Winner
    mapping(uint256 => Winner) private _roundWinners;
    /// @notice winnings is a mapping of user to their winnings
    /// @dev address => winnings amount
    mapping(address => uint256) public winnings;

    //Arrays
    /// @notice nftBoostLookup is an array of the NFT boost lookup table
    /// @dev The array index is the number of NFTs owned, the value is the boost in % with a scale of 10000
    uint256[26] public nftBoostLookup = [
        0,
        345,
        540,
        675,
        765,
        840,
        900,
        960,
        1005,
        1050,
        1080,
        1100,
        1155,
        1185,
        1215,
        1245,
        1275,
        1305,
        1335,
        1365,
        1380,
        1400,
        1440,
        1455,
        1470,
        1500
    ];

    constructor(
        address _yeetTokenAddress,
        Reward _reward,
        StakeV2 _staking,
        YeetGameSettings _gameSettings,
        address _publicGoodsAddress,
        address _teamAddress,
        address _yeetardsNFTsAddress,
        address _entropy,
        address _entropyProvider
    ) Ownable(msg.sender) Pausable() {
        require(_publicGoodsAddress != address(0), "Invalid public goods address");
        require(_teamAddress != address(0), "Invalid team address");
        require(_yeetTokenAddress != address(0), "Invalid yeet token address");

        yeetTokenAddress = _yeetTokenAddress;
        rewardsContract = _reward;
        stakingContract = _staking;
        gameSettings = _gameSettings;
        publicGoodsAddress = _publicGoodsAddress;
        treasuryRevenueAddress = _teamAddress;
        yeetardsNFTsAddress = _yeetardsNFTsAddress;

        yeetback = new Yeetback(_entropy, _entropyProvider);
        copySettings();

        lastYeetedAt = block.timestamp;
        endOfYeetTime = block.timestamp + YEET_TIME_SECONDS + BOOSTRAP_PHASE_DURATION;
        roundStartTime = block.timestamp;
        emit RoundStarted(
            roundNumber,
            block.timestamp,
            YEET_TIME_SECONDS,
            POT_DIVISION,
            TAX_PER_YEET,
            TAX_TO_STAKERS,
            TAX_TO_PUBLIC_GOODS,
            TAX_TO_TREASURY,
            YEETBACK_PERCENTAGE,
            COOLDOWN_TIME
        );
    }

    /// @notice this function is used to yeet without any tokenIds (no NFTs)
    function yeet() external payable {
        _yeet(new uint256[](0));
    }

    /// @notice this function is used to yeet with tokenIds (NFTs)
    function yeet(uint256[] memory tokenIds) external payable {
        _yeet(tokenIds);
    }

    /// @notice yeet is the main function of the game, users yeet the native token in the pot
    /// @param tokenIds the tokenIds of the NFTs the user owns, used to calculate the boost
    function _yeet(uint256[] memory tokenIds) internal {
        _verifyTokenIds(tokenIds);

        uint256 timestamp = block.timestamp;
        if (timestamp >= endOfYeetTime) {
            revert YeetTimePassed(timestamp, endOfYeetTime);
        }

        uint256 minimumYeetPoint = _minimumYeetPoint(potToWinner);
        if (msg.value < minimumYeetPoint) {
            revert InsufficientYeet(msg.value, minimumYeetPoint);
        }

        (uint256 valueToPot, uint256 valueToYeetback, uint256 valueToStakers, uint256 publicGoods, uint256 teamRevenue)
        = getDistribution(msg.value);

        publicGoodsAmount += publicGoods;
        treasuryRevenueAmount += teamRevenue;

        yeetTimeInSeconds = YEET_TIME_SECONDS;
        uint256 timeLeftOnTimer = endOfYeetTime - timestamp;

        potToYeetback += valueToYeetback;
        potToWinner += valueToPot;
        nrOfYeets += 1;
        lastYeeted = msg.sender;
        lastYeetedAt = timestamp;
        if (isBoostrapPhase()) {
            endOfYeetTime = roundStartTime + yeetTimeInSeconds + BOOSTRAP_PHASE_DURATION;
        } else {
            endOfYeetTime = timestamp + yeetTimeInSeconds;
        }

        // Useful for the for stats and history
        emit YeetDistribution(msg.value, valueToPot, valueToYeetback, valueToStakers, publicGoods, teamRevenue);
        emit Yeet(
            msg.sender,
            timestamp,
            TAX_PER_YEET,
            valueToPot,
            valueToYeetback,
            potToWinner,
            potToYeetback,
            yeetTimeInSeconds,
            _minimumYeetPoint(potToWinner),
            nrOfYeets,
            roundNumber,
            timeLeftOnTimer
        );
        if (isBoostrapPhase()) {
            uint256 amountOfTickers = msg.value / minimumYeetPoint;
            for (uint256 i = 0; i < amountOfTickers; i++) {
                yeetback.addYeetsInRound(roundNumber, msg.sender);
            }
        } else {
            yeetback.addYeetsInRound(roundNumber, msg.sender);
        }

        uint256 boostedValue = getBoostedValue(msg.sender, valueToPot, tokenIds);
        rewardsContract.addYeetVolume(msg.sender, boostedValue);
        stakingContract.depositReward{value: valueToStakers}();
    }

    /// @notice claim is the function the winner uses to claim their winnings
    function claim() external nonReentrant {
        if (winnings[msg.sender] == 0) {
            revert NoWinningsToClaim(msg.sender);
        }

        uint256 valueWon = winnings[msg.sender];
        winnings[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: valueWon}("");
        require(success, "Transfer failed.");
        emit Claim(msg.sender, block.timestamp, valueWon);
    }

    function hasCooldownEnded() public view returns (bool) {
        return block.timestamp >= endOfYeetTime + COOLDOWN_TIME;
    }

    /// @notice restart is the function that restarts the game, any user can call this function after the yeet time has passed
    /// @dev The function will pay out the yeetback pot to random users that yeeted in the round
    function restart(bytes32 userRandomNumber) external payable whenNotPaused {
        if (userRandomNumber == bytes32(0)) {
            revert InvalidRandomNumber();
        }

        if (!isRoundFinished()) {
            revert RoundStillLive(roundNumber);
        }

        if (!hasCooldownEnded()) {
            revert CooldownNotEnded(block.timestamp, endOfYeetTime + COOLDOWN_TIME);
        }

        emit RoundWinner(lastYeeted, block.timestamp, potToWinner, roundNumber, nrOfYeets);

        uint256 fee = yeetback.getEntropyFee();
        if (msg.value < fee) {
            revert NotEnoughValueToPayEntropyFee(msg.value, fee);
        }
        uint256 remaining = msg.value - fee;

        if (potToYeetback > 0) {
            yeetback.addYeetback{value: fee + potToYeetback}(userRandomNumber, roundNumber, potToYeetback);
        }

        winnings[lastYeeted] += potToWinner;

        _roundWinners[roundNumber] = Winner(lastYeeted, block.timestamp, potToWinner, roundNumber);

        copySettings();
        roundNumber += 1;
        potToYeetback = 0;
        potToWinner = 0;
        nrOfYeets = 0;
        lastYeeted = address(0);
        lastYeetedAt = 0;
        yeetTimeInSeconds = YEET_TIME_SECONDS;
        endOfYeetTime = block.timestamp + yeetTimeInSeconds + BOOSTRAP_PHASE_DURATION;
        roundStartTime = block.timestamp;

        if (remaining > 0) {
            (bool success,) = payable(msg.sender).call{value: remaining}("");
            require(success, "Transfer failed, cant return remaining value to sender");
        }

        emit RoundStarted(
            roundNumber,
            roundStartTime,
            YEET_TIME_SECONDS,
            POT_DIVISION,
            TAX_PER_YEET,
            TAX_TO_STAKERS,
            TAX_TO_PUBLIC_GOODS,
            TAX_TO_TREASURY,
            YEETBACK_PERCENTAGE,
            COOLDOWN_TIME
        );
    }

    function isRoundFinished() public view returns (bool) {
        return block.timestamp >= endOfYeetTime;
    }

    /// @notice getMinimumYeetPoint is a function that returns the minimum yeet amount needed to yeet
    /// @return uint256 the minimum yeet amount
    function minimumYeetPoint() public view returns (uint256) {
        return _minimumYeetPoint(potToWinner);
    }

    /// @notice getDistribution is a function that returns the distribution of the yeet amount
    /// @param yeetAmount the amount yeeted
    /// @return uint256 the value to the pot
    /// @return uint256 the value to the yeetback
    /// @return uint256 the value to the stakers
    /// @return uint256 the value to public goods
    /// @return uint256 the value to the treasury
    function getDistribution(uint256 yeetAmount) public view returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 scale = gameSettings.SCALE();

        uint256 valueAfterTax = (yeetAmount / scale) * (scale - TAX_PER_YEET);
        uint256 valueToYeetBack = (yeetAmount / scale) * (YEETBACK_PERCENTAGE);
        uint256 valueToPot = (yeetAmount / scale) * (scale - YEETBACK_PERCENTAGE - TAX_PER_YEET);
        uint256 tax = yeetAmount - valueAfterTax;

        uint256 valueToStakers = (tax / scale) * TAX_TO_STAKERS;
        uint256 publicGoods = (tax / scale) * TAX_TO_PUBLIC_GOODS;
        uint256 teamRevenue = (tax / scale) * TAX_TO_TREASURY;

        return (valueToPot, valueToYeetBack, valueToStakers, publicGoods, teamRevenue);
    }

    /// @notice _minimumYeetPoint is a function that returns the minimum yeet amount needed to yeet
    /// @param totalPot the total pot
    /// @return uint256 the minimum yeet amount
    function _minimumYeetPoint(uint256 totalPot) private view returns (uint256) {
        if (totalPot == 0) {
            return MINIMUM_YEET_POINT;
        }

        if (isBoostrapPhase()) {
            return MINIMUM_YEET_POINT;
        }

        uint256 min = totalPot / POT_DIVISION;
        if (min < MINIMUM_YEET_POINT) {
            return MINIMUM_YEET_POINT;
        }
        return min;
    }

    /// @notice getWinner is a function that returns the winner of a round
    /// @param round the round to get the winner of
    /// @return Winner the winner of the round
    function getWinner(uint256 round) public view returns (Winner memory) {
        return _roundWinners[round];
    }

    /// @notice Add a fallback function to accept BERA
    fallback() external payable {
        //Sucks to be you ;)
        potToWinner += msg.value;
        emit Yeetard(msg.sender, block.timestamp, potToWinner, _minimumYeetPoint(potToWinner), roundNumber);
    }

    /// @notice Add a receive function to accept BERA
    receive() external payable {
        //Sucks to be you ;)
        potToWinner += msg.value;
        emit Yeetard(msg.sender, block.timestamp, potToWinner, _minimumYeetPoint(potToWinner), roundNumber);
    }

    /// @notice generic payout function
    function _payout(uint256 amount, address payable recipient, string memory errorMessage) private {
        require(amount != 0, errorMessage);
        uint256 payoutAmount = amount;
        (bool success,) = recipient.call{value: payoutAmount}("");
        require(success, "Transfer failed.");
    }

    /// @notice payoutPublicGoods is a function that pays out the public goods tax to the public goods address
    function payoutPublicGoods() external onlyOwner nonReentrant {
        _payout(publicGoodsAmount, payable(publicGoodsAddress), "Yeet: No public goods to pay out");
        emit PublicGoodsPaidOut(publicGoodsAddress, block.timestamp, publicGoodsAmount);
        publicGoodsAmount = 0;
    }

    /// @notice payoutTreasuryRevenue is a function that pays out the treasury revenue tax to the treasury revenue address
    function payoutTreasuryRevenue() external onlyOwner nonReentrant {
        _payout(treasuryRevenueAmount, payable(treasuryRevenueAddress), "Yeet: No Treasury revenue to pay out");
        emit TreasuryRevenuePaidOut(treasuryRevenueAddress, block.timestamp, treasuryRevenueAmount);
        treasuryRevenueAmount = 0;
    }

    /// @notice setPublicGoodsAddress allows the owner to set the public goods address
    function setPublicGoodsAddress(address _publicGoodsAddress) external onlyOwner {
        require(_publicGoodsAddress != address(0), "Invalid public goods address");
        publicGoodsAddress = _publicGoodsAddress;
        emit UpdatedPublicGoodsAddress(_publicGoodsAddress);
    }

    /// @notice setTreasuryRevenueAddress allows the owner to set the treasury revenue address
    function setTreasuryRevenueAddress(address _treasuryRevenueAddress) external onlyOwner {
        require(_treasuryRevenueAddress != address(0), "Invalid treasury revenue address");
        treasuryRevenueAddress = _treasuryRevenueAddress;
        emit UpdatedTreasuryRevenueAddress(_treasuryRevenueAddress);
    }

    /// @notice setYeetardsNFTsAddress allows the owner to set the NFT contract address
    // We might launche the game before we can bridge the NFTs
    function setYeetardsNFTsAddress(address _yeetardsNFTsAddress) external onlyOwner {
        require(_yeetardsNFTsAddress != address(0), "Invalid yeetards NFTs address");
        yeetardsNFTsAddress = _yeetardsNFTsAddress;
        emit UpdatedYeetardsNFTsAddress(_yeetardsNFTsAddress);
    }

    /// @notice updateStakingContract allows the owner to update the staking contract, used for new on vaults
    function updateStakingContract(StakeV2 _staking) external onlyOwner {
        stakingContract = _staking;
    }

    /// @notice copySettings is a function that copies the settings from the YeetGameSettings contract, that way settings cant be changed mid round
    function copySettings() internal {
        YEET_TIME_SECONDS = gameSettings.YEET_TIME_SECONDS();
        POT_DIVISION = gameSettings.POT_DIVISION();
        TAX_PER_YEET = gameSettings.TAX_PER_YEET();
        TAX_TO_STAKERS = gameSettings.TAX_TO_STAKERS();
        TAX_TO_PUBLIC_GOODS = gameSettings.TAX_TO_PUBLIC_GOODS();
        TAX_TO_TREASURY = gameSettings.TAX_TO_TREASURY();
        YEETBACK_PERCENTAGE = gameSettings.YEETBACK_PERCENTAGE();
        COOLDOWN_TIME = gameSettings.COOLDOWN_TIME();
        BOOSTRAP_PHASE_DURATION = gameSettings.BOOSTRAP_PHASE_DURATION();
        MINIMUM_YEET_POINT = gameSettings.MINIMUM_YEET_POINT();
    }

    /// @notice getBoostedValue is a function that returns the boosted value of a yeet based on how many NFTs the user owns
    /// @param sender the user that yeeted
    /// @param value the value of the yeet
    /// @param tokenIds the tokenIds of the NFTs the user owns
    /// @return uint256 the boosted value
    function getBoostedValue(address sender, uint256 value, uint256[] memory tokenIds) public view returns (uint256) {
        uint256 nftBoost = getNFTBoost(sender, tokenIds);
        return value + (value * nftBoost) / 10000;
    }

    function isBoostrapPhase() public view returns (bool) {
        return block.timestamp < roundStartTime + BOOSTRAP_PHASE_DURATION;
    }

    /// @notice getNFTBoost is a function that returns the NFT boost of a user based on how many NFTs the user owns
    function getNFTBoost(address owner, uint256[] memory tokenIds) public view returns (uint256) {
        _verifyTokenIds(tokenIds);
        if (yeetardsNFTsAddress == address(0)) {
            return 0;
        }
        INFTContract nftContract = INFTContract(yeetardsNFTsAddress);

        uint256 balance = tokenIds.length;
        for (uint256 i = 0; i < balance; i++) {
            // make sure the user is the owner of all the tokensIds
            uint256 tokenId = tokenIds[i];
            if (nftContract.ownerOf(tokenId) != owner) {
                revert UserDoesNotOwnNFTs(owner, tokenId);
            }
        }

        if (balance > nftBoostLookup.length - 1) {
            return nftBoostLookup[nftBoostLookup.length - 1];
        }

        return nftBoostLookup[balance];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _verifyTokenIds(uint256[] memory tokenIds) internal view {
        if (tokenIds.length > nftBoostLookup.length) {
            revert ToManyTokenIds(tokenIds.length);
        }

        if (tokenIds.length == 0) {
            return;
        }

        for (uint256 i = 0; i < tokenIds.length - 1; i++) {
            if (tokenIds[i] >= tokenIds[i + 1]) {
                revert DuplicateTokenId(tokenIds[i]);
            }
        }
    }
}
