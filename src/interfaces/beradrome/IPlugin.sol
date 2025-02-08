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

interface IPlugin {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function claimAndDistribute() external;

    function depositFor(address account, uint256 amount) external;

    function withdrawTo(address account, uint256 amount) external;

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function setGauge(address gauge) external;

    function setBribe(address bribe) external;

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getUnderlyingName() external view returns (string memory);

    function getUnderlyingSymbol() external view returns (string memory);

    function getUnderlyingAddress() external view returns (address);

    function getProtocol() external view returns (string memory);

    function getTokensInUnderlying() external view returns (address[] memory);

    function getBribeTokens() external view returns (address[] memory);

    function getUnderlyingDecimals() external view returns (uint8);

    /*----------  ERRORS ------------------------------------------------*/

    error Plugin__InvalidZeroInput();
    error Plugin__NotAuthorizedVoter();

    /*----------  EVENTS ------------------------------------------------*/

    event Plugin__Deposited(address indexed account, uint256 amount);
    event Plugin__Withdrawn(address indexed account, uint256 amount);
}
