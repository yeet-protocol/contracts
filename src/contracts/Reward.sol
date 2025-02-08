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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import {RewardSettings} from "./RewardSettings.sol";

/// @title OnlyYeet
/// @notice A contract that only allows the Yeet contract to call certain functions
contract OnlyYeetContract is Ownable2Step {
    address public yeetContract;

    constructor(address _owner) Ownable(_owner) {}

    modifier onlyYeetOwner() {
        require(msg.sender == yeetContract, "Only yeet contract can call this function");
        _;
    }

    function setYeetContract(address _yeetContract) external onlyOwner {
        require(_yeetContract != address(0), "Invalid address");
        yeetContract = _yeetContract;
    }
}

/// @title Emission contract based on YEETING volume
/// @notice This contract is responsible for distributing rewards based on the volume of YEET that each address does under a certain period of time
contract Reward is OnlyYeetContract {
    /// @notice The token to be distributed as rewards
    IERC20 public token;
    /// @notice The settings for the rewards
    RewardSettings public rewardsSettings;

    /// @notice The total volume of YEET for each epoch
    /// @dev epoch => total volume
    mapping(uint256 => uint256) public totalYeetVolume;
    /// @notice The volume of YEET for each user in each epoch
    /// @dev epoch => user => volume
    mapping(uint256 => mapping(address => uint256)) public userYeetVolume;

    /// @notice The duration of each distribution period
    uint256 private constant DISTRIBUTION_CHANGE = 7 days;
    /// @notice The amount of tokens to be distributed in the first distribution period, eg DISTRIBUTION_CHANGE
    uint256 private constant STARTING_TOKEN_COUNT = 1_312_810 ether;
    /// @notice The length of each epoch in seconds
    uint256 private constant EPOCH_LENGTH = 1 days;
    /// @notice The rate at which the rewards decay
    /// @dev 50 = 0,5% decay per DISTRIBUTION_CHANGE period
    uint256 private constant DECAY_RATE = 50;
    /// @notice The scaling factor for fixed-point arithmetic
    uint256 private constant SCALE_FACTOR = 1e4;

    /// @notice The rewards for each epoch
    /// @dev epoch => rewards
    mapping(uint256 => uint256) public epochRewards;
    /// @notice The last epoch that a user has claimed rewards for
    /// @dev user => epoch
    /// @dev This field is to keep track of the last epoch that a user has claimed, not what epoch the user claimed in, but up to what epoch the user has claimed rewards for.
    mapping(address => uint256) public lastClaimedForEpoch;

    /// @notice The current epoch
    uint256 public currentEpoch;
    /// @notice The timestamp of the end of the current epoch
    uint256 public currentEpochEnd;
    /// @notice The timestamp of the start of the current epoch
    uint256 public currentEpochStart;

    event Rewarded(address indexed user, uint256 amount, uint256 timestamp);
    event EpochStarted(uint256 indexed epoch, uint256 startTime, uint256 endTime, uint256 rewards);
    event ParsecSkipper(address user, uint256 startEpoch, uint256 endEpoch);

    /// @param _token: The token to be distributed as rewards
    /// @param _settings: The settings for the rewards
    constructor(IERC20 _token, RewardSettings _settings) OnlyYeetContract(msg.sender) {
        token = _token;
        rewardsSettings = _settings;
        currentEpochStart = getLastMidnight();
        currentEpochEnd = _calculateEpochEnd();
        currentEpoch = 1;
        epochRewards[currentEpoch] = STARTING_TOKEN_COUNT / (DISTRIBUTION_CHANGE / EPOCH_LENGTH);
        emit EpochStarted(currentEpoch, currentEpochStart, currentEpochEnd, epochRewards[currentEpoch]);
    }

    function getEpochRewardsForCurrentEpoch() public view returns (uint256) {
        return epochRewards[currentEpoch];
    }

    function getLastMidnight() public view returns (uint256) {
        return block.timestamp - (block.timestamp % 1 days);
    }

    function clawbackTokens(uint256 tokenAmount) external onlyOwner {
        bool success = token.transfer(owner(), tokenAmount);
        require(success, "ClawbackTokens: Transfer failed");
    }

    /// @notice Add volume to a user's YEET volume, and the total YEET volume for the current epoch.
    /// @notice If the epoch has ended, end the epoch.
    /// @dev Only the YEET contract can call this function
    function addYeetVolume(address user, uint256 amount) external onlyYeetOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(user != address(0), "Invalid user address");

        if (_shouldEndEpoch()) {
            _endEpoch();
        }

        userYeetVolume[currentEpoch][user] += amount;
        totalYeetVolume[currentEpoch] += amount;
    }

    /// @notice Claim the rewards for the sender
    function claim() external {
        uint256 amountEarned = getClaimableAmount(msg.sender);
        require(amountEarned != 0, "Nothing to claim");
        require(token.balanceOf(address(this)) >= amountEarned, "Not enough tokens in contract");

        lastClaimedForEpoch[msg.sender] = currentEpoch - 1; // This should be the fix.
        token.transfer(msg.sender, amountEarned);
        emit Rewarded(msg.sender, amountEarned, block.timestamp);
    }

    /// @dev We could potentially have a problem here where we jump over multiple epochs
    function _endEpoch() private {
        // Check if it's time to decay the rewards
        if (currentEpoch % (DISTRIBUTION_CHANGE / EPOCH_LENGTH) == 0) {
            uint256 decayAmount = (epochRewards[currentEpoch] * DECAY_RATE) / SCALE_FACTOR;
            epochRewards[currentEpoch + 1] = epochRewards[currentEpoch] - decayAmount;
        } else {
            epochRewards[currentEpoch + 1] = epochRewards[currentEpoch];
        }

        currentEpoch++;
        currentEpochStart = currentEpochEnd;
        currentEpochEnd = _calculateEpochEnd();
        emit EpochStarted(currentEpoch, currentEpochStart, currentEpochEnd, epochRewards[currentEpoch]);
    }

    /// @notice This function sets the epoch to a specific value, its used for new users to save gas on the first claim
    /// @dev calling this function risk losing rewards for the skipped epochs
    /// @dev ONLY CALL THIS FUNCTION IF YOU KNOW WHAT YOU ARE DOING, there is no way to revert this action.
    function punchItChewie(uint256 epoch) external {
        uint256 lastEndedEpoch = currentEpoch - 1;
        uint256 lastClaimedEpoch = lastClaimedForEpoch[msg.sender];
        require(epoch <= lastEndedEpoch, "Can't jump to the future");
        require(epoch > lastClaimedEpoch, "Can't jump to the past");

        lastClaimedForEpoch[msg.sender] = epoch;
        emit ParsecSkipper(msg.sender, lastClaimedEpoch, epoch);
    }

    /// @notice Calculate the amount of tokens that a user can claim
    /// @dev if no one yeets, the epoch will never end, and the user can never claim (should not really be a problem)
    function getClaimableAmount(address user) public view returns (uint256) {
        uint256 totalClaimable;

        // Fixed-point arithmetic for more precision
        uint256 scalingFactor = 1e18;

        for (uint256 epoch = lastClaimedForEpoch[user] + 1; epoch < currentEpoch; epoch++) {
            if (totalYeetVolume[epoch] == 0) continue; // Avoid division by zero

            uint256 userVolume = userYeetVolume[epoch][user];
            uint256 totalVolume = totalYeetVolume[epoch];

            uint256 userShare = (userVolume * scalingFactor) / totalVolume;

            uint256 maxClaimable = (epochRewards[epoch] / rewardsSettings.MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR());
            uint256 claimable = (userShare * epochRewards[epoch]) / scalingFactor;

            if (claimable > maxClaimable) {
                claimable = maxClaimable;
            }

            totalClaimable += claimable;
        }

        return totalClaimable;
    }

    function _calculateEpochEnd() private view returns (uint256) {
        return currentEpochStart + EPOCH_LENGTH;
    }

    function _shouldEndEpoch() private view returns (bool) {
        return block.timestamp >= currentEpochEnd;
    }
}
