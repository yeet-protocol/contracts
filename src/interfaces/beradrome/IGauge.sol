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
pragma solidity ^0.8.20;

interface IGauge {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;

    function notifyRewardAmount(address token, uint256 amount) external;

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(address account, uint256 amount) external;

    function _withdraw(address account, uint256 amount) external;

    function addReward(address rewardToken) external;

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function rewardPerToken(address reward) external view returns (uint256);

    function getRewardForDuration(address reward) external view returns (uint256);

    function earned(address account, address reward) external view returns (uint256);

    function left(address token) external view returns (uint256);

    function getRewardTokens() external view returns (address[] memory);
}
