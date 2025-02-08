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

/// @title RewardSettings, a contract for managing reward settings
/// @notice This contract allows the owner to set the reward settings to be used by the reward contract
contract RewardSettings is Ownable2Step {
    /// @dev The max rewards a wallet can get per epoch
    uint256 public MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR;

    event YeetRewardSettingsChanged(uint256 indexed maxCapPerWalletPerEpoch);

    constructor() Ownable(msg.sender) {
        /// @dev this is in percentage, 1/10 of the total rewards
        MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR = 30;
    }

    /// @notice Set the reward settings
    /// @param _maxCapPerWalletPerEpochFactor The max rewards a wallet can get per epoch
    /// @dev This function can only be called by the owner
    function setYeetRewardsSettings(uint256 _maxCapPerWalletPerEpochFactor) external onlyOwner {
        require(
            _maxCapPerWalletPerEpochFactor >= 1,
            "YeetRewardSettings: maxCapPerWalletPerEpochFactor must be greater than 1"
        ); // 1/1 of the total rewards
        require(
            _maxCapPerWalletPerEpochFactor <= 100,
            "YeetRewardSettings: maxCapPerWalletPerEpochFactor must be less than 100"
        ); // 1/100 of the total rewards

        MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR = _maxCapPerWalletPerEpochFactor;

        emit YeetRewardSettingsChanged(MAX_CAP_PER_WALLET_PER_EPOCH_FACTOR);
    }
}
