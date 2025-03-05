// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IKodiakV1RouterStaking} from "interfaces/kodiak/IKodiakV1RouterStaking.sol";
import {IOBRouter} from "interfaces/oogabooga/IOBRouter.sol";
import {IZapper} from "interfaces/IZapper.sol";

contract SimpleZapperMock is IZapper {
    uint256 public amountIslandTokens;
    uint256 public amountShares;
    IOBRouter public swapRouterValue;
    IKodiakV1RouterStaking public kodiakStakingRouterValue;
    uint32 public referralCodeValue;
    uint256 public _zapOutNativeReturnValue;
    IERC20 public token0;
    IERC20 public token1;

    constructor(IERC20 _token0, IERC20 _token1) {
        amountIslandTokens = 0;
        amountShares = 0;
        token0 = _token0;
        token1 = _token1;
    }

    function setReturnValues(uint256 _amountIslandTokens, uint256 _amountShares) external {
        amountIslandTokens = _amountIslandTokens;
        amountShares = _amountShares;
    }

    function zapInWithoutSwap(KodiakVaultStakingParams calldata, VaultDepositParams calldata)
    external
    returns (uint256, uint256)
    {
        return (amountIslandTokens, amountShares);
    }

    function zapInToken0(IZapper.SingleTokenSwap calldata a, KodiakVaultStakingParams calldata, VaultDepositParams calldata)
    external
    returns (uint256, uint256)
    {
        token0.transferFrom(msg.sender, address(this), a.inputAmount);
        return (amountIslandTokens, amountShares);
    }

    function zapInToken1(SingleTokenSwap calldata a, KodiakVaultStakingParams calldata, VaultDepositParams calldata)
    external
    returns (uint256, uint256)
    {
        require(token1.allowance(msg.sender, address(this)) >= a.inputAmount, "Allowance not set");
        token1.transferFrom(msg.sender, address(this), a.inputAmount);
        return (amountIslandTokens, amountShares);
    }

    function zapIn(
        address,
        SingleTokenSwap calldata,
        SingleTokenSwap calldata,
        KodiakVaultStakingParams calldata,
        VaultDepositParams calldata
    ) external returns (uint256, uint256) {
        return (amountIslandTokens, amountShares);
    }

    function zapInNative(
        SingleTokenSwap calldata,
        SingleTokenSwap calldata,
        KodiakVaultStakingParams calldata,
        VaultDepositParams calldata
    ) external payable returns (uint256, uint256) {
        return (amountIslandTokens, amountShares);
    }

    function zapOutToToken0(
        address,
        SingleTokenSwap calldata,
        KodiakVaultUnstakingParams calldata,
        VaultRedeemParams calldata
    ) external pure returns (uint256) {
        return 0;
    }

    function zapOutToToken1(
        address,
        SingleTokenSwap calldata,
        KodiakVaultUnstakingParams calldata,
        VaultRedeemParams calldata
    ) external pure returns (uint256) {
        return 0;
    }

    function zapOutNative(
        address,
        SingleTokenSwap calldata,
        SingleTokenSwap calldata,
        KodiakVaultUnstakingParams calldata,
        VaultRedeemParams calldata
    ) external returns (uint256) {
        return _zapOutNativeReturnValue;
    }

    function setZapOutNativeReturn(uint256 value) external {
        _zapOutNativeReturnValue = value;
    }

    function zapOut(
        address,
        address,
        SingleTokenSwap calldata,
        SingleTokenSwap calldata,
        KodiakVaultUnstakingParams calldata,
        VaultRedeemParams calldata
    ) external pure returns (uint256) {
        return 0;
    }

    function zapInWithMultipleTokens(
        MultiSwapParams calldata,
        KodiakVaultStakingParams calldata,
        VaultDepositParams calldata
    ) external returns (uint256, uint256) {
        return (amountIslandTokens, amountShares);
    }

    function setSwapRouter(address _swapRouter) external {
        swapRouterValue = IOBRouter(_swapRouter);
    }

    function updateSwappableTokens(address, bool) external pure {}

    function updateWhitelistedKodiakVault(address, bool) external pure {}

    function setKodiakStakingRouter(address router) external {
        kodiakStakingRouterValue = IKodiakV1RouterStaking(router);
    }

    function setReferralCode(uint32 code) external {
        referralCodeValue = code;
    }

    function setCompoundingVault(address, bool) external pure {}

    function swapRouter() external view returns (IOBRouter) {
        return swapRouterValue;
    }

    function kodiakStakingRouter() external view returns (IKodiakV1RouterStaking) {
        return kodiakStakingRouterValue;
    }

    function referralCode() external view returns (uint32) {
        return referralCodeValue;
    }
}
