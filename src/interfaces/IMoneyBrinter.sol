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
import "./beradrome/IPlugin.sol";
import "./beradrome/IGauge.sol";
import "./IZapper.sol";

pragma solidity ^0.8.20;

interface IMoneyBrinter {
    // events
    event FeeCollected(address indexed caller, address indexed owner, address indexed treasury, uint256 fees);
    event KodiakRewardsHarvested(address indexed harvestor, address[] previousKodiakRewardTokens);
    event BeradromeRewardsHarvested(address indexed harvestor);
    event VaultCompounded(address indexed strategyManager, uint256 compoundAmount);
    event ExitFeeBasisPointsSet(uint256 oldFeeBps, uint256 newFeeBps);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event ZapperUpdated(address oldZapper, address newZapper);
    event StrategyManagerUpdated(address manager, bool isWhitelisted);
    event XKdkUpdated(address oldXKdk, address newXKdk);
    event xKDKAllocationFlagUpdated(bool oldFlag, bool flag);
    event KodiakRewardsUpdated(address oldKodiakRewards, address newKodiakRewards);

    function maxAllowedFeeBps() external view returns (uint256);

    function beradromeFarmPlugin() external view returns (IPlugin);

    function beradromeFarmRewardsGauge() external view returns (IGauge);

    function kodiakRewards() external view returns (address);

    function xKdk() external view returns (address);

    function zapper() external view returns (IZapper);

    function allocateXKDKToKodiakRewards() external view returns (bool);

    function treasury() external view returns (address);

    function strategyManager(address) external view returns (bool);

    function exitFeeBasisPoints() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function harvestKodiakRewards(address[] calldata previousKodiakRewardTokens) external;

    function harvestBeradromeRewards() external;

    function compound(
        address[] calldata swapInputTokens,
        IZapper.SingleTokenSwap[] calldata swapToToken0,
        IZapper.SingleTokenSwap[] calldata swapToToken1,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultStakingParams
    ) external returns (uint256);

    function setExitFeeBasisPoints(uint256 newFeeBps) external;

    function setTreasury(address newTreasury) external;

    function setZapper(address newZapper) external;

    function setStrategyManager(address manager, bool isWhitelisted) external;

    // function setBeradromeFarmPlugin(address newBeradromeFarmPlugin) external;

    function setAllocationFlagxKDK(bool flag) external;

    // function setBeradromeFarmRewardsGauge(address newGauge) external;

    function setXKdk(address newXKdk) external;

    function setKodiakRewards(address newKodiakRewards) external;

    function initiateRedeem(uint256 amount, uint256 duration) external;

    function finalizeRedeem(uint256 redeemIndex) external;

    function updateRedeemRewardsAddress(uint256 redeemIndex) external;

    function cancelRedeem(uint256 redeemIndex) external;

    function deallocateXKDK(uint256 amount) external;
}
