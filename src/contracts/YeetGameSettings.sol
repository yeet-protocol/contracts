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

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title YeetGameSettings
/// @notice This contract is used to store the settings for the YeetGame
/// @notice Chaning the settings will affect the next round of the game
contract YeetGameSettings is Ownable2Step {
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

    uint256 public constant SCALE = 10000;

    event YeetSettingsChanged(
        uint256 yeetTimeSeconds,
        uint256 potDivision,
        uint256 taxPerYeet,
        uint256 taxToStakers,
        uint256 taxToPublicGoods,
        uint256 taxToTreasury,
        uint256 yeetbackPercentage,
        uint256 cooldownTime,
        uint256 bootstrapPhaseDuration,
        uint256 minimumYeetPoint
    );

    constructor() Ownable(msg.sender) {
        YEET_TIME_SECONDS = 1 hours;
        POT_DIVISION = 200;

        TAX_PER_YEET = 1000;
        TAX_TO_STAKERS = 7000;
        TAX_TO_PUBLIC_GOODS = 1000;
        TAX_TO_TREASURY = 2000;
        YEETBACK_PERCENTAGE = 2000;
        COOLDOWN_TIME = 0 hours;
        BOOSTRAP_PHASE_DURATION = 0 hours;
        MINIMUM_YEET_POINT = 0.001 ether;
    }

    /// @notice Set the settings for the YeetGame
    /// @param _yeetTimeSeconds The time between yeets
    /// @param _potDivision 1/xth of the pot eg, x%, 1/200 = 0.5%
    /// @param _taxPerYeet The tax per yeet in %
    /// @param _taxToStakers The tax to stakers in %
    /// @param _taxToPublicGoods The tax to public goods in %
    /// @param _taxToTreasury The tax to treasury in %
    /// @param _yeetbackPercentage The percentage of the pot that goes to yeetback
    /// @param _cooldownTime The time between rounds
    /// @dev All values are in basis points except _yeetTimeSeconds, _cooldownTime and _potDivision
    function setYeetSettings(
        uint256 _yeetTimeSeconds,
        uint256 _potDivision,
        uint256 _taxPerYeet,
        uint256 _taxToStakers,
        uint256 _taxToPublicGoods,
        uint256 _taxToTreasury,
        uint256 _yeetbackPercentage,
        uint256 _cooldownTime,
        uint256 _bootstrapPhaseDuration,
        uint256 _minimumYeetPoint
    ) external onlyOwner {
        require(_yeetTimeSeconds >= 60, "YeetGameSettings: yeetTimeSeconds must be greater than 60 seconds");
        require(_yeetTimeSeconds <= 1 days, "YeetGameSettings: yeetTimeSeconds must be less than 1 day");

        require(_potDivision >= 10, "YeetGameSettings: potDivision must be greater than 10"); // 10% of the pot
        require(_potDivision <= 1000, "YeetGameSettings: potDivision must be less than 1000"); // 0.1% of the pot

        require(_taxPerYeet >= 100, "YeetGameSettings: taxPerYeet must be greater than 1%");
        require(_taxPerYeet <= 2000, "YeetGameSettings: taxPerYeet must be less than 20%");

        require(_taxToStakers >= 5000, "YeetGameSettings: taxToStakers must be greater than 50%");
        require(_taxToStakers <= 9000, "YeetGameSettings: taxToStakers must be less than 90%");

        require(_taxToPublicGoods >= 0, "YeetGameSettings: taxToPublicGoods must be positive");
        require(_taxToPublicGoods <= 2000, "YeetGameSettings: taxToPublicGoods must be less than 20%");

        require(_taxToTreasury >= 0, "YeetGameSettings: taxToTreasury must be positive");
        require(_taxToTreasury <= 5000, "YeetGameSettings: taxToTreasury must be less than 50%");

        require(_yeetbackPercentage >= 0, "YeetGameSettings: yeetbackPercentage must be positive");
        require(_yeetbackPercentage <= 2000, "YeetGameSettings: yeetbackPercentage must be less than 20%");

        require(
            _taxToStakers + _taxToPublicGoods + _taxToTreasury == 10000,
            "YeetGameSettings: taxToStakers + taxToPublicGoods + taxToTreasury must equal 100%"
        );

        require(_cooldownTime <= 3 days, "YeetGameSettings: cooldownTime must be less than 3 day");

        require(_bootstrapPhaseDuration <= 3 days, "YeetGameSettings: bootstrapPhaseDuration must be less than 3 day");
        require(_bootstrapPhaseDuration >= 0, "YeetGameSettings: bootstrapPhaseDuration must be greater than 0");

        require(_minimumYeetPoint >= 0.001 ether, "YeetGameSettings: minimumYeetPoint must be greater than 0.001 ether");

        YEET_TIME_SECONDS = _yeetTimeSeconds;
        POT_DIVISION = _potDivision;
        TAX_PER_YEET = _taxPerYeet;
        TAX_TO_STAKERS = _taxToStakers;
        TAX_TO_PUBLIC_GOODS = _taxToPublicGoods;
        TAX_TO_TREASURY = _taxToTreasury;
        YEETBACK_PERCENTAGE = _yeetbackPercentage;
        COOLDOWN_TIME = _cooldownTime;
        BOOSTRAP_PHASE_DURATION = _bootstrapPhaseDuration;
        MINIMUM_YEET_POINT = _minimumYeetPoint;

        emit YeetSettingsChanged(
            YEET_TIME_SECONDS,
            POT_DIVISION,
            TAX_PER_YEET,
            TAX_TO_STAKERS,
            TAX_TO_PUBLIC_GOODS,
            TAX_TO_TREASURY,
            YEETBACK_PERCENTAGE,
            COOLDOWN_TIME,
            BOOSTRAP_PHASE_DURATION,
            MINIMUM_YEET_POINT
        );
    }
}
