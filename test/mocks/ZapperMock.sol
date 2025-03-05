// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZapper} from "interfaces/IZapper.sol";
import {Zapper} from "contracts/Zapper.sol";
import {IOBRouter} from "interfaces/oogabooga/IOBRouter.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IKodiakVaultV1} from "interfaces/kodiak/IKodiakVaultV1.sol";

contract ZapperMock is Zapper {
    address public  WBERA = 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8;
    constructor(address _swapRouter, address _kodiakV1RouterStaking) Zapper(_swapRouter, _kodiakV1RouterStaking, WBERA) {}

    function publicVerifyTokenAndSwap(
        SingleTokenSwap calldata swapData,
        address inputToken,
        address outputToken,
        address receiver
    ) public returns (uint256 amountOut) {
        return _verifyTokenAndSwap(swapData, inputToken, outputToken, receiver);
    }

    function publicApproveRouterAndSwap(
        IOBRouter.swapTokenInfo memory swapTokenInfo,
        bytes calldata path,
        address executor
    ) public returns (uint256 amountOut) {
        return _approveRouterAndSwap(swapTokenInfo, path, executor);
    }

    function publicPerformMultiSwaps(address vault, IZapper.MultiSwapParams calldata swapParams)
    public
    returns (uint256 token0Debt, uint256 token1Debt)
    {
        IERC20 token0 = IKodiakVaultV1(vault).token0();
        IERC20 token1 = IKodiakVaultV1(vault).token1();
        return _performMultiSwaps(token0, token1, swapParams);
    }

    function publicYeetIn(
        IERC20 token0,
        IERC20 token1,
        uint256 amount0,
        uint256 amount1,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) public returns (uint256, uint256) {
        return _yeetIn(token0, token1, amount0, amount1, stakingParams, vaultParams);
    }

    function publicYeetOut(VaultRedeemParams calldata redeemParams, KodiakVaultUnstakingParams calldata unstakeParams)
    public
    returns (IERC20 token0, IERC20 token1, uint256 amountOut0, uint256 amountOut1)
    {
        return _yeetOut(redeemParams, unstakeParams);
    }

    function publicClearUserDebt(IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt, address receiver)
    public
    {
        _clearUserDebt(token0, token1, token0Debt, token1Debt, receiver);
    }

    function publicUnstakeFromIsland(IZapper.KodiakVaultUnstakingParams calldata unstakeParams, uint256 burnAmount)
    public
    returns (IERC20 token0, IERC20 token1, uint256 amountOut0, uint256 amountOut1)
    {
        return _approveAndUnstakeFromKodiakVault(unstakeParams, burnAmount);
    }

    function publicDepositIntoVault(IZapper.VaultDepositParams calldata vaultParams, uint256 kodiakVaultTokensMinted)
    public
    returns (uint256)
    {
        return _depositIntoVault(vaultParams, kodiakVaultTokensMinted);
    }

    function publicWithdrawFromVault(IZapper.VaultRedeemParams calldata redeemParams) public returns (uint256) {
        return _withdrawFromVault(redeemParams);
    }

    function publicApproveAndAddLiquidityToKodiakVault(
        address kodiakVault,
        IERC20 token0,
        IERC20 token1,
        IZapper.KodiakVaultStakingParams calldata stakingParams
    ) public returns (uint256, uint256, uint256) {
        return _approveAndAddLiquidityToKodiakVault(kodiakVault, token0, token1, stakingParams);
    }
}
