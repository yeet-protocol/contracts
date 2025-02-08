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

import {IOBRouter} from "./oogabooga/IOBRouter.sol";
import {IKodiakV1RouterStaking} from "./kodiak/IKodiakV1RouterStaking.sol";
import {IKodiakVaultV1} from "./kodiak/IKodiakVaultV1.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IZapper {
    struct MultiSwapParams {
        address[] inputTokens;
        SingleTokenSwap[] swapToToken0;
        SingleTokenSwap[] swapToToken1;
    }

    struct VaultDepositParams {
        address vault;
        address receiver;
        uint256 minShares; // front-running protection!!
    }

    struct VaultRedeemParams {
        address vault;
        address receiver;
        uint256 shares;
        uint256 minAssets; // front-running protection!!
    }

    struct KodiakVaultStakingParams {
        address kodiakVault;
        uint256 amount0Max;
        uint256 amount1Max;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 amountSharesMin;
        address receiver;
    }

    struct KodiakVaultUnstakingParams {
        address kodiakVault;
        uint256 amount0Min;
        uint256 amount1Min;
        address receiver;
    }

    struct SingleTokenSwap {
        uint256 inputAmount;
        uint256 outputQuote;
        uint256 outputMin;
        address executor;
        bytes path;
    }

    function zapInWithoutSwap(KodiakVaultStakingParams calldata stakingParams, VaultDepositParams calldata vaultParams)
        external
        returns (uint256 islandTokensReceived, uint256 vaultSharesReceived);

    function zapInToken0(
        SingleTokenSwap calldata swapData,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256 vaultAssetsReceived, uint256 vaultSharesMinted);

    function zapInToken1(
        SingleTokenSwap calldata swapData,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256 vaultAssetsReceived, uint256 vaultSharesMinted);

    function zapIn(
        address inputToken,
        SingleTokenSwap calldata swapToToken0,
        SingleTokenSwap calldata swapToToken1,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256, uint256);

    function zapInNative(
        SingleTokenSwap calldata swap0,
        SingleTokenSwap calldata swap1,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultParams
    ) external payable returns (uint256, uint256);

    function zapOutToToken0(
        address receiver,
        SingleTokenSwap calldata swapData,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) external returns (uint256 totalAmountOut);

    function zapOutToToken1(
        address receiver,
        SingleTokenSwap calldata swapData,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) external returns (uint256 totalAmountOut);

    function zapOutNative(
        address receiver,
        SingleTokenSwap calldata swapData0,
        SingleTokenSwap calldata swapData1,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) external returns (uint256 totalAmountOut);

    function zapOut(
        address outputToken,
        address receiver,
        SingleTokenSwap calldata swap0,
        SingleTokenSwap calldata swap1,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) external returns (uint256 totalAmountOut);

    function zapInWithMultipleTokens(
        MultiSwapParams calldata swapParams,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) external returns (uint256, uint256);

    function setSwapRouter(address _swapRouter) external;

    function updateSwappableTokens(address token, bool isWhitelisted) external;

    function updateWhitelistedKodiakVault(address vault, bool isWhitelisted) external;

    function setKodiakStakingRouter(address router) external;

    function setReferralCode(uint32 code) external;

    function setCompoundingVault(address vault, bool isWhitelisted) external;

    function swapRouter() external view returns (IOBRouter);

    function kodiakStakingRouter() external view returns (IKodiakV1RouterStaking);

    function referralCode() external view returns (uint32);
}
