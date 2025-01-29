// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IGauge} from "./IGauge.sol";
import {IKodiakVaultV1} from "./IKodiakVaultV1.sol";

interface IKodiakV1RouterStaking {
    function addLiquidity(
        IKodiakVaultV1 pool,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquidityETH(
        IKodiakVaultV1 pool,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquidityAndStake(
        IGauge gauge,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquidityETHAndStake(
        IGauge gauge,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function removeLiquidity(
        IKodiakVaultV1 pool,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function removeLiquidityETH(
        IKodiakVaultV1 pool,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address payable receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function removeLiquidityAndUnstake(
        IGauge gauge,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function removeLiquidityETHAndUnstake(
        IGauge gauge,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address payable receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
}

// | Function Name | Sighash    | Function Signature |
// | ------------- | ---------- | ------------------ |
// | initialize | 8129fc1c | initialize() |
// | pause | 8456cb59 | pause() |
// | unpause | 3f4ba83a | unpause() |
// | addLiquidity | 74dbc248 | addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address) |
// | addLiquidityAndStake | a6446c89 | addLiquidityAndStake(address,uint256,uint256,uint256,uint256,uint256,address) |
// | addLiquidityETH | 938398b7 | addLiquidityETH(address,uint256,uint256,uint256,uint256,uint256,address) |
// | addLiquidityETHAndStake | 8c220973 | addLiquidityETHAndStake(address,uint256,uint256,uint256,uint256,uint256,address) |
// | removeLiquidity | 59f842b2 | removeLiquidity(address,uint256,uint256,uint256,address) |
// | removeLiquidityAndUnstake | b83a75b3 | removeLiquidityAndUnstake(address,uint256,uint256,uint256,address) |
// | removeLiquidityETH | 6587e4ce | removeLiquidityETH(address,uint256,uint256,uint256,address) |
// | removeLiquidityETHAndUnstake | 5de56ba8 | removeLiquidityETHAndUnstake(address,uint256,uint256,uint256,address) |
