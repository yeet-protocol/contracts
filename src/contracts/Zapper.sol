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

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "forge-std/console.sol";

import {IZapper} from "../interfaces/IZapper.sol";
import {IKodiakV1RouterStaking} from "../interfaces/kodiak/IKodiakV1RouterStaking.sol";
import {IOBRouter} from "../interfaces/oogabooga/IOBRouter.sol";
import {IMoneyBrinter} from "../interfaces/IMoneyBrinter.sol";
import {IKodiakVaultV1} from "../interfaces/kodiak/IKodiakVaultV1.sol";
import {IWETH} from "../interfaces/IWETH.sol";

    struct SwapNativeResult {
        IERC20 token0;
        IERC20 token1;
        uint256 token0Debt;
        uint256 token1Debt;
        uint256 wBeraDebt;
    }

/**
 * @title Zapper
 * @dev A contract that facilitates efficient entry and exit from Kodiak vaults and compounding vaults abstracting the process into a single function across multiple steps involving swaps, liquidityProvision, staking and vice versa.
 *
 * The Zapper contract allows users to:
 * 1. Deposit single or multiple tokens into Kodiak vaults and compounding vaults.
 * 2. Withdraw from vaults and receive single or multiple tokens.
 * 3. Perform necessary token swaps using the OogaBooga router.
 * 4. Handle native token (BERA) deposits and withdrawals.
 * 5. Can drop in/out at any step of the process.
 * 6. Zap in -> swap -> stake -> deposit to compounding vault
 * 7. Zap out -> redeem -> unstake -> swap from kodiak vault
 *
 * Key features:
 * - Supports single or multistep process for swapping and staking, allowing for flexibility in the swap and stake process.
 * - Can zap in using one or more whitelisted tokens or native token.
 * - Can zap out to one whitelisted token or native token
 * - Integrates with OogaBooga router for token swaps.
 * - Manages whitelisted kodiak and compounding vaults and whitelisted tokens for security.
 * - Implements slippage protection for user transactions in between swaps and final step of staking/unstaking
 * - Returns any unused tokens to the msgSender and credits the output to the apprpriate receiver
 *
 * The contract is designed to be flexible and extensible, allowing for easy addition
 * of new vaults and tokens. It also includes safety measures such as reentrancy protection
 * and ownership controls for whitelisting vaults and tokens.
 */
contract Zapper is IZapper, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IOBRouter public swapRouter; // oogabooga router address
    IKodiakV1RouterStaking public kodiakStakingRouter;
    IWETH public wbera;
    uint32 public referralCode = 2; // OogaBooga referral code
    mapping(address => bool) public whitelistedCompoundingVaults;
    mapping(address => bool) public whitelistedKodiakVaults;
    mapping(address => bool) public whitelistedTokens;

    event TokenWhitelisted(address token, bool isWhitelisted);

    constructor(address _swapRouter, address _kodiakV1RouterStaking, address _wbera) Ownable(_msgSender()) {
        require(
            _swapRouter != address(0) && _kodiakV1RouterStaking != address(0),
            "Zapper: swap router or staking router zero address"
        );
        swapRouter = IOBRouter(_swapRouter);
        kodiakStakingRouter = IKodiakV1RouterStaking(_kodiakV1RouterStaking);
        wbera = IWETH(_wbera);
    }

    modifier onlyWhitelistedKodiakVaults(address vault) {
        require(whitelistedKodiakVaults[vault], "Zapper: Kodiak vault not whitelisted");
        _;
    }

    // ############################ public functions ############################

    /**
     * @dev Zaps into vault using token0 and token1 sourced directly from the user.
     * @param stakingParams The parameters required for staking in the vault.
     * @param vaultParams The parameters required for depositing into the vault.
     * @return islandTokensReceived  The total island tokens minted
     * @return vaultSharesReceived The total vault shares minted to
     */
    function zapInWithoutSwap(KodiakVaultStakingParams calldata stakingParams, VaultDepositParams calldata vaultParams)
    public
    override
    nonReentrant
    onlyWhitelistedKodiakVaults(stakingParams.kodiakVault)
    returns (uint256 islandTokensReceived, uint256 vaultSharesReceived)
    {
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();
        token0.safeTransferFrom(_msgSender(), address(this), stakingParams.amount0Max);
        token1.safeTransferFrom(_msgSender(), address(this), stakingParams.amount1Max);
        (islandTokensReceived, vaultSharesReceived) =
        _yeetIn(token0, token1, stakingParams.amount0Max, stakingParams.amount1Max, stakingParams, vaultParams);
    }

    /**
     * @dev Zaps into vault using native token (Bera), converts to Wbera, then swaps for both token0 and token1 if needed, mints island tokens, and deposits into a vault.
     * @param swapData0 The information required for swapping Wbera to token0 (if token0 is not Wbera).
     * @param swapData1 The information required for swapping Wbera to token1 (if token1 is not Wbera).
     * @param stakingParams The parameters required for staking in the vault.
     * @param vaultParams The parameters required for depositing into the vault.
     * @return islandTokensReceived  The total island tokens minted
     * @return vaultSharesReceived The total vault shares minted to
     */
    function zapInNative(
        SingleTokenSwap calldata swapData0,
        SingleTokenSwap calldata swapData1,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultParams
    )
    public
    payable
    nonReentrant
    onlyWhitelistedKodiakVaults(stakingParams.kodiakVault)
    returns (uint256 islandTokensReceived, uint256 vaultSharesReceived)
    {
        // Call _swapNativeToTokens and store the result in the struct
        SwapNativeResult memory swapResult = _swapNativeToTokens(swapData0, swapData1, stakingParams.kodiakVault);

        // Use the struct members in the subsequent _yeetIn call
        (islandTokensReceived, vaultSharesReceived) = _yeetIn(
            swapResult.token0,
            swapResult.token1,
            swapResult.token0Debt,
            swapResult.token1Debt,
            stakingParams,
            vaultParams
        );

        _sendNativeToken(_msgSender(), swapResult.wBeraDebt);
        return (islandTokensReceived, vaultSharesReceived);
    }

    /**
     * @dev Zaps into vault using token0, swaps token0 for token1, mints island tokens,deposit the island tokens into a vault.
     * @param swapData The information required for the token swap. The input token should be Wbera/Yeet. The output token should be the other token.
     * @param stakingParams The parameters required for staking in the vault.
     * @param vaultParams The parameters required for depositing into the vault.
     * @return The total island tokens minted and the total vault shares minted.
     */
    function zapInToken0(
        SingleTokenSwap calldata swapData,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(stakingParams.kodiakVault) returns (uint256, uint256) {
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();
        token0.safeTransferFrom(_msgSender(), address(this), stakingParams.amount0Max + swapData.inputAmount);
        uint256 token1Debt = _verifyTokenAndSwap(swapData, address(token0), address(token1), address(this)); // @audit -> only token1 can be used extra in the vault staking.
        return _yeetIn(token0, token1, stakingParams.amount0Max, token1Debt, stakingParams, vaultParams);
    }

    /// @notice Zaps into vault using token1, swaps token1 for token0, mints island tokens,deposit the island tokens into a vault.
    /// @param swapData The information required for the token swap. The input token should be Wbera/Yeet. The output token should be the other token.
    /// @param stakingParams The parameters required for staking in the vault.
    /// @param vaultParams The parameters required for depositing into the vault.
    /// @return The total island tokens minted and the total vault shares minted.
    function zapInToken1(
        SingleTokenSwap calldata swapData,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(stakingParams.kodiakVault) returns (uint256, uint256) {
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();
        token1.safeTransferFrom(_msgSender(), address(this), stakingParams.amount1Max + swapData.inputAmount);
        uint256 token0Debt = _verifyTokenAndSwap(swapData, address(token1), address(token0), address(this));
        return _yeetIn(token0, token1, token0Debt, stakingParams.amount1Max, stakingParams, vaultParams);
    }

    /**
     * @dev Zaps into vault using a whitelisted token, swaps this token for token 0 and token 1, mints island tokens,deposit the island tokens into a vault.
     * @param inputToken The address of the whitelisted token.
     * @param swapToToken0 swap data for swapping inputToken to token0
     * @param swapToToken1 swap data for swapping inputToken to token1
     * @param stakingParams The parameters required for staking in the vault.
     * @param vaultParams The parameters required for depositing into the vault.
     * @return The total island tokens minted and the total vault shares minted.
     */
    function zapIn(
        address inputToken,
        SingleTokenSwap calldata swapToToken0,
        SingleTokenSwap calldata swapToToken1,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(stakingParams.kodiakVault) returns (uint256, uint256) {
        // @note -> what happens if token0 or token1 is inputToken? Would ooga booga revert?
        // fetch user token
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();
        IERC20(inputToken).safeTransferFrom(
            _msgSender(), address(this), swapToToken0.inputAmount + swapToToken1.inputAmount
        );
        uint256 token0debt = _verifyTokenAndSwap(swapToToken0, inputToken, address(token0), address(this));
        uint256 token1debt = _verifyTokenAndSwap(swapToToken1, inputToken, address(token1), address(this));
        return _yeetIn(token0, token1, token0debt, token1debt, stakingParams, vaultParams);
    }

    /// @notice Zaps into vault using multiple tokens at once. Swaps these tokens for token 0 and token 1, mints island tokens, and deposits the island tokens into a vault.
    /// @param swapParams The parameters required for the multi swap.
    /// @param stakingParams The parameters required for staking in the vault.
    /// @param vaultParams The parameters required for depositing into the vault.
    /// @return The total island tokens minted and the total vault shares minted.
    function zapInWithMultipleTokens(
        MultiSwapParams calldata swapParams,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(stakingParams.kodiakVault) returns (uint256, uint256) {
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();
        // loop and swap Input tokens with corresponding swapData
        (uint256 _token0Debt, uint256 token1Debt) = _performMultiSwaps(token0, token1, swapParams);
        return _yeetIn(token0, token1, _token0Debt, token1Debt, stakingParams, vaultParams);
    }

    /// @notice Zaps out to get token0
    /// @param receiver The address to receive the output tokens
    /// @param swapData The swap data for converting token1 to token0
    /// @param unstakeParams Parameters for unstaking from the Kodiak Vault
    /// @param redeemParams Parameters for redeeming from the vault
    /// @return totalToken0Out The total amount of token0 received

    function zapOutToToken0(
        address receiver,
        SingleTokenSwap calldata swapData,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(unstakeParams.kodiakVault) returns (uint256 totalToken0Out) {
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) = _yeetOut(redeemParams, unstakeParams);
        if (token0Debt == 0 && token1Debt == 0) {
            return (0);
        }
        token1Debt -= swapData.inputAmount;
        token0Debt += _verifyTokenAndSwap(swapData, address(token1), address(token0), address(this));
        _sendERC20Token(token0, receiver, token0Debt);
        _sendERC20Token(token1, _msgSender(), token1Debt);
        return (token0Debt);
    }

    /// @notice Zaps out to get token1
    /// @param receiver The address to receive the output tokens
    /// @param swapData The swap data for converting token0 to token1
    /// @param unstakeParams Parameters for unstaking from the Kodiak Vault
    /// @param redeemParams Parameters for redeeming from the vault
    /// @return totalToken1Out The total amount of token1 received
    function zapOutToToken1(
        address receiver,
        SingleTokenSwap calldata swapData,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(unstakeParams.kodiakVault) returns (uint256 totalToken1Out) {
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) = _yeetOut(redeemParams, unstakeParams);
        if (token0Debt == 0 && token1Debt == 0) {
            return (0);
        }
        token0Debt -= swapData.inputAmount;
        token1Debt += _verifyTokenAndSwap(swapData, address(token0), address(token1), address(this));
        _sendERC20Token(token0, _msgSender(), token0Debt);
        _sendERC20Token(token1, receiver, token1Debt);
        return (token1Debt);
    }

    /// @notice Zaps out of the vault to native BERA token.
    /// @param receiver The address to receive the native BERA
    /// @param swapData0 The swap data for converting token0 to WBERA
    /// @param swapData1 The swap data for converting token1 to WBERA
    /// @param unstakeParams Parameters for unstaking from the Kodiak Vault
    /// @param redeemParams Parameters for redeeming from the vault
    /// @return totalNativeOut The total amount of native BERA received
    /// @dev Bera is sent to the receiver. Any extra token0 and token1 is sent back to the _msgSender().
    /// @dev integrating contracts must handle any returned token0 and token1
    function zapOutNative(
        address receiver,
        SingleTokenSwap calldata swapData0,
        SingleTokenSwap calldata swapData1,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        IZapper.VaultRedeemParams calldata redeemParams
    ) public nonReentrant onlyWhitelistedKodiakVaults(unstakeParams.kodiakVault) returns (uint256 totalNativeOut) {
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) = _yeetOut(redeemParams, unstakeParams);
        if (token0Debt == 0 && token1Debt == 0) {
            return (0);
        }

        totalNativeOut = _swapToWBERA(token0, token1, token0Debt, token1Debt, swapData0, swapData1);
        _sendNativeToken(receiver, totalNativeOut);
    }

    /// @notice Zaps out of a vault using dual token swaps. Used when the output token is neither token 0 nor token 1.
    /// @param outputToken The address of the desired output token
    /// @param receiver The address to receive the output tokens
    /// @param swap0 The swap data for token swap from token0 to Output token. Receiver should be set to final receiver not zapper.
    /// @param swap1 The swap data for token swap from token1 to Output token. Receiver should be set to final receiver not zapper.
    /// @param unstakeParams Parameters for unstaking from the Kodiak Vault
    /// @param redeemParams Parameters for redeeming from the vault
    /// @return totalAmountOut The total amount of output tokens received
    function zapOut(
        address outputToken,
        address receiver,
        SingleTokenSwap calldata swap0,
        SingleTokenSwap calldata swap1,
        KodiakVaultUnstakingParams calldata unstakeParams,
        VaultRedeemParams calldata redeemParams
    )
    public
    override
    nonReentrant
    onlyWhitelistedKodiakVaults(unstakeParams.kodiakVault)
    returns (uint256 totalAmountOut)
    {
        (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) = _yeetOut(redeemParams, unstakeParams);
        if (token0Debt == 0 && token1Debt == 0) {
            return totalAmountOut;
        }
        // @note -> Do I need to check this, what happens if I don't.
        if (outputToken == address(token0)) {
            revert("Zapper: Invalid output token");
        } else if (outputToken == address(token1)) {
            revert("Zapper: Invalid output token");
        } else {
            // sent directly to receiver. What is receiver is zapper?
            totalAmountOut += _verifyTokenAndSwap(swap0, address(token0), outputToken, receiver);
            token0Debt -= swap0.inputAmount;
            totalAmountOut += _verifyTokenAndSwap(swap1, address(token1), outputToken, receiver);
            token1Debt -= swap1.inputAmount;
        }
        _clearUserDebt(token0, token1, token0Debt, token1Debt, _msgSender());
    }

    // ############################ Admin functions ############################

    function setSwapRouter(address _swapRouter) external override onlyOwner {
        require(_swapRouter != address(0), "Zapper: swapRouter is zero address");
        swapRouter = IOBRouter(_swapRouter);
    }

    function setCompoundingVault(address vault, bool isWhitelisted) external override onlyOwner {
        require(vault != address(0), "Zapper: vault is zero address");
        whitelistedCompoundingVaults[vault] = isWhitelisted;
    }

    function updateSwappableTokens(address token, bool isWhitelisted) external override onlyOwner {
        _updateWhitelistedTokens(token, isWhitelisted);
    }

    function setKodiakStakingRouter(address router) external override onlyOwner {
        require(router != address(0), "Zapper: router is zero address");
        kodiakStakingRouter = IKodiakV1RouterStaking(router);
        // @todo check vault's token vs router's token for compatibility
    }

    function updateWhitelistedKodiakVault(address vault, bool isEnabled) external override onlyOwner {
        require(vault != address(0), "Zapper: vault is zero address");
        whitelistedKodiakVaults[vault] = isEnabled;
        address token0 = address(IKodiakVaultV1(vault).token0());
        address token1 = address(IKodiakVaultV1(vault).token1());
        require(token0 != address(0) && token1 != address(0) && token0 != token1, "Zapper: invalid token0 or token1");
        // whitelist tokens if not already whitelisted
        if (!whitelistedTokens[token0]) {
            _updateWhitelistedTokens(token0, true);
        }
        if (!whitelistedTokens[token1]) {
            _updateWhitelistedTokens(token1, true);
        }
    }

    function setReferralCode(uint32 code) external override onlyOwner {
        referralCode = code;
    }

    // ############################ private functions ############################

    /// @notice white list or blacklist a token
    /// @param token The address of the token
    /// @param isWhitelisted The status of the token
    function _updateWhitelistedTokens(address token, bool isWhitelisted) private {
        require(token != address(0), "Zapper: token is zero address");
        whitelistedTokens[token] = isWhitelisted;
        emit TokenWhitelisted(token, isWhitelisted);
    }

    /// @notice Sends native token (BERA) to the receiver
    /// @param receiver Address to receive native BERA
    /// @param amount Amount of native BERA to send
    function _sendNativeToken(address receiver, uint256 amount) internal {
        if (amount > 0) {
            wbera.withdraw(amount);
            payable(receiver).transfer(amount);
        }
    }

    /// @notice Sends ERC20 token to the receiver
    /// @param token Address of the ERC20 token
    /// @param receiver Address to receive the ERC20 token
    /// @param amount Amount of the ERC20 token to send
    function _sendERC20Token(IERC20 token, address receiver, uint256 amount) internal {
        require(receiver != address(this), "Zapper: clearing user debt to zapper");
        if (amount > 0) {
            token.safeTransfer(receiver, amount);
        }
    }

    /// @notice Clears the user debt from the zapper.
    /// @dev Clears the user debt from the zapper and sends back to the receiver.
    /// @param token0 The address of the token0
    /// @param token1 The address of the token1
    /// @param token0Debt The amount of token0 to clear
    /// @param token1Debt The amount of token1 to clear
    /// @param receiver The address to receive the unused token0 and token1
    function _clearUserDebt(IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt, address receiver)
    internal
    {
        _sendERC20Token(token0, receiver, token0Debt);
        _sendERC20Token(token1, receiver, token1Debt);
    }

    /// @notice Burns vault shares, if receiver is zapper, proceeds to unstaking from the island to get token0 and token1.
    /// @param redeemParams The parameters for redeeming from the vault
    /// @param unstakeParams The parameters for unstaking from the Kodiak Vault
    /// @return token0 from kodiak vault.
    /// @return token1 from kodiak vault.
    /// @return token0Debt The amount of token0 received by zapper for end receiver[0 if token0 and token1 are sent directly to receiver another than zapper using unstakeParams]
    /// @return token1Debt The amount of token1 received by zapper for end receiver[0 if token0 and token1 are sent directly to receiver another than zapper using unstakeParams]
    function _yeetOut(
        IZapper.VaultRedeemParams calldata redeemParams,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams
    ) internal returns (IERC20 token0, IERC20 token1, uint256 token0Debt, uint256 token1Debt) {
        uint256 islandTokensReceived = _withdrawFromVault(redeemParams);
        if (redeemParams.receiver == address(this)) {
            (token0, token1, token0Debt, token1Debt) =
            _approveAndUnstakeFromKodiakVault(unstakeParams, islandTokensReceived);
            if (unstakeParams.receiver != address(this)) {
                return (IERC20(address(0)), IERC20(address(0)), 0, 0);
            }
        }
    }

    // @audit -> token0Debt and token1Debt are the amounts of token0 and token1 that zapper holds for the current user tx.
    // @dev -> Assumes that token0Debt and token1Debt are already acquired from the user.
    // verifies if token0Debt and token1Debt are greater than stakingParams.amount0Max and stakingParams.amount1Max
    // deposits tokens to get island tokens.
    // If staking receiver is zapper, then deposit island tokens to vault
    // the token0Debt and token1Debt are cleared after deducting the amount used in island staking.
    // Debt is sent back to the _msgSender(). if a contract is using the zapper they need to handle the returned unused token0 and token1
    function _yeetIn(
        IERC20 token0,
        IERC20 token1,
        uint256 token0Debt,
        uint256 token1Debt,
        KodiakVaultStakingParams calldata stakingParams,
        VaultDepositParams calldata vaultParams
    ) internal returns (uint256, uint256) {
        (uint256 amount0Used, uint256 amount1Used, uint256 kodiakVaultTokensMinted) =
                        _approveAndAddLiquidityToKodiakVault(stakingParams.kodiakVault, token0, token1, stakingParams);
        // @audit -> reverts if negative. hence user cannot use more than what he has.
        token0Debt -= amount0Used;
        token1Debt -= amount1Used;
        uint256 vaultSharesMinted;
        // if recevier is zapper then deposit into vault
        if (stakingParams.receiver == address(this) && kodiakVaultTokensMinted > 0) {
            vaultSharesMinted = _depositIntoVault(vaultParams, kodiakVaultTokensMinted);
        }
        _clearUserDebt(token0, token1, token0Debt, token1Debt, _msgSender());
        return (kodiakVaultTokensMinted, vaultSharesMinted);
    }

    /// @notice Adds liquidity to Kodiak Vault and returns the amount of token0used, token1used and IslandTokens minted
    /// @param kodiakVault The address of the Kodiak Vault
    /// @param token0 The address of the token0
    /// @param token1 The address of the token1
    /// @param stakingParams The parameters for staking
    /// @dev Requires that slippage is respected by the destination island. (amount0Min, amount1Min, amountSharesMin)
    /// @dev @audit Requires that token0(amount0Max) and token1(amount1Max) are already acquired from the msg.sender()
    function _approveAndAddLiquidityToKodiakVault(
        address kodiakVault,
        IERC20 token0,
        IERC20 token1,
        IZapper.KodiakVaultStakingParams calldata stakingParams
    ) internal returns (uint256, uint256, uint256) {
        require(kodiakVault != address(0), "Zapper: invalid zero address kodiakVault in staking params");
        // add liquidity to destination Island
        token0.safeIncreaseAllowance(address(kodiakStakingRouter), stakingParams.amount0Max);
        token1.safeIncreaseAllowance(address(kodiakStakingRouter), stakingParams.amount1Max);
        // add liquidity using KodiakStakingRouter
        return kodiakStakingRouter.addLiquidity(
            IKodiakVaultV1(kodiakVault),
            stakingParams.amount0Max,
            stakingParams.amount1Max,
            stakingParams.amount0Min,
            stakingParams.amount1Min,
            stakingParams.amountSharesMin,
            stakingParams.receiver
        );
    }

    /// @notice Unstakes the islandTokenDebt amount owed to user from the kodiakVault
    /// @param unstakeParams The parameters for unstaking from the Kodiak Vault
    /// @param islandTokenDebt The amount of island tokens that are acquired from the user.
    /// @return token0 of vault
    /// @return token1 of vault
    /// @return amount0 The amount of token0 received by user/zapper
    /// @return amount1 The amount of token1 received by user/zapper
    function _approveAndUnstakeFromKodiakVault(
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        uint256 islandTokenDebt
    ) internal returns (IERC20, IERC20, uint256, uint256) {
        // unstake from destination Island
        IERC20 _token0 = IKodiakVaultV1(unstakeParams.kodiakVault).token0();
        IERC20 _token1 = IKodiakVaultV1(unstakeParams.kodiakVault).token1();
        require(unstakeParams.receiver != address(0), "Zapper: zero address beneficiary");
        IERC20(address(unstakeParams.kodiakVault)).safeIncreaseAllowance(address(kodiakStakingRouter), islandTokenDebt);
        (uint256 _amount0, uint256 _amount1,) = kodiakStakingRouter.removeLiquidity(
            IKodiakVaultV1(unstakeParams.kodiakVault),
            islandTokenDebt,
            unstakeParams.amount0Min,
            unstakeParams.amount1Min,
            unstakeParams.receiver
        );

        // require(islandTokenDebt == _liqBurned, "Invalid island token burn amount");
        return (_token0, _token1, _amount0, _amount1);
    }

    // Checks if the vault is whitelisted and if the receiver is not the zero address.
    // Increases allowance of island tokens to vault and calls previewDeposit.
    // If shares are less than minShares, it reverts. [slippage check]
    // Deposits island tokens into vault and if receiver is zapper, it sends vault shares to user.
    function _depositIntoVault(IZapper.VaultDepositParams calldata vaultParams, uint256 kodiakVaultTokensMinted)
    internal
    returns (uint256)
    {
        require(vaultParams.receiver != address(0), "Zapper: zero address beneficiary");
        require(whitelistedCompoundingVaults[vaultParams.vault], "Zapper: vault not whitelisted");
        // get vault asset address
        address asset = IERC4626(vaultParams.vault).asset();
        uint256 shares = IERC4626(vaultParams.vault).previewDeposit(kodiakVaultTokensMinted);
        if (shares < vaultParams.minShares) {
            revert("Zapper: insufficient shares minted");
        }
        IERC20(asset).safeIncreaseAllowance(vaultParams.vault, kodiakVaultTokensMinted);
        IERC4626(vaultParams.vault).deposit(kodiakVaultTokensMinted, vaultParams.receiver);
        // if receiver is zapper, then send vault shares to user
        if (vaultParams.receiver == address(this)) {
            IERC20(vaultParams.vault).transfer(_msgSender(), shares);
        }
        return shares;
    }

    /// @notice Gets vault shares from _msgSender(), Redeems shares from the vault and returns the amount of island tokens received
    /// @param redeemParams The parameters for redeeming from the vault
    /// @return islandTokensReceived The amount of island tokens received
    /// Enforces slippage using the minAssets parameter from the redeemParams.
    function _withdrawFromVault(IZapper.VaultRedeemParams calldata redeemParams) internal returns (uint256) {
        // spend allowance of island tokens to zapper is needed.
        require(redeemParams.receiver != address(0), "Zapper: zero address beneficiary");
        require(whitelistedCompoundingVaults[redeemParams.vault], "Zapper: vault not whitelisted");
        // get shares from user.
        IERC20(redeemParams.vault).safeTransferFrom(_msgSender(), address(this), redeemParams.shares);
        uint256 islandTokensReceived =
                                IERC4626(redeemParams.vault).redeem(redeemParams.shares, redeemParams.receiver, address(this));
        require(islandTokensReceived >= redeemParams.minAssets, "Zapper: insufficient assets received");
        return islandTokensReceived;
    }

    /// @notice Swaps tokens to WBERA, returns any unused token0 and token1 back to _msg
    /// @param token0 address of token0
    /// @param token1 address of token1
    /// @param token0Debt Amount of token0 to swap
    /// @param token1Debt Amount of token1 to swap
    /// @param swapData0 Swap data for converting token0 to WBERA
    /// @param swapData1 Swap data for converting token1 to WBERA
    /// @return wBeraDebt Total amount of WBERA received
    function _swapToWBERA(
        IERC20 token0,
        IERC20 token1,
        uint256 token0Debt,
        uint256 token1Debt,
        SingleTokenSwap calldata swapData0,
        SingleTokenSwap calldata swapData1
    ) internal returns (uint256 wBeraDebt) {
        if (address(token0) == address(wbera)) {
            wBeraDebt += token0Debt;
            token0Debt = 0;
        } else {
            wBeraDebt += _verifyTokenAndSwap(swapData0, address(token0), address(wbera), address(this));
            token0Debt -= swapData0.inputAmount;
        }

        if (address(token1) == address(wbera)) {
            wBeraDebt += token1Debt;
            token1Debt = 0;
        } else {
            wBeraDebt += _verifyTokenAndSwap(swapData1, address(token1), address(wbera), address(this));
            token1Debt -= swapData1.inputAmount;
        }
        // log yeetBalance
        _clearUserDebt(token0, token1, token0Debt, token1Debt, _msgSender());
    }

    /**
     * @dev Swaps native Bera (as Wbera) to token0 and token1 as needed.
     * @param swapData0 The swap data for token0.
     * @param swapData1 The swap data for token1.
     * @param kodiakVault The address of the Kodiak vault.
     * @return swapResult The result of the swap.
     */
    function _swapNativeToTokens(
        SingleTokenSwap calldata swapData0,
        SingleTokenSwap calldata swapData1,
        address kodiakVault
    ) private returns (SwapNativeResult memory swapResult) {
        // Convert native to Wbera
        wbera.deposit{value: msg.value}();
        swapResult.token0 = IKodiakVaultV1(kodiakVault).token0();
        swapResult.token1 = IKodiakVaultV1(kodiakVault).token1();
        swapResult.wBeraDebt = msg.value;

        // since token0 and token1 cannot be the same, the following logic works
        if (address(swapResult.token0) == address(wbera)) {
            swapResult.token1Debt =
                            _verifyTokenAndSwap(swapData1, address(wbera), address(swapResult.token1), address(this));
            swapResult.token0Debt = swapResult.wBeraDebt - swapData1.inputAmount;
            swapResult.wBeraDebt = 0;
        } else if (address(swapResult.token1) == address(wbera)) {
            swapResult.token0Debt =
                            _verifyTokenAndSwap(swapData0, address(wbera), address(swapResult.token0), address(this));
            swapResult.token1Debt = swapResult.wBeraDebt - swapData0.inputAmount;
            swapResult.wBeraDebt = 0;
        } else {
            swapResult.token0Debt =
                            _verifyTokenAndSwap(swapData0, address(wbera), address(swapResult.token0), address(this));
            swapResult.token1Debt =
                            _verifyTokenAndSwap(swapData1, address(wbera), address(swapResult.token1), address(this));
            swapResult.wBeraDebt -= (swapData0.inputAmount + swapData1.inputAmount);
        }
    }

    function _performMultiSwaps(IERC20 token0, IERC20 token1, MultiSwapParams calldata params)
    internal
    returns (uint256 token0Debt, uint256 token1Debt)
    {
        require(
            params.inputTokens.length == params.swapToToken0.length + params.swapToToken1.length,
            "Zapper: Swap Array disparity"
        );
        for (uint256 i = 0; i < params.swapToToken0.length; i++) {
            // fetch user token
            IERC20(params.inputTokens[i]).safeTransferFrom(
                _msgSender(), address(this), params.swapToToken0[i].inputAmount
            );
            token0Debt +=
                            _verifyTokenAndSwap(params.swapToToken0[i], params.inputTokens[i], address(token0), address(this));
        }
        for (uint256 i = params.swapToToken0.length; i < params.inputTokens.length; i++) {
            // fetch user token
            IERC20(params.inputTokens[i]).safeTransferFrom(
                _msgSender(), address(this), params.swapToToken1[i - params.swapToToken0.length].inputAmount
            );
            token1Debt += _verifyTokenAndSwap(
                params.swapToToken1[i - params.swapToToken0.length],
                params.inputTokens[i],
                address(token1),
                address(this)
            );
        }
    }

    // @audit -> Assumes tokens have been acquired from the user.
    function _verifyTokenAndSwap(
        SingleTokenSwap calldata swapData,
        address inputToken,
        address outputToken,
        address receiver
    ) internal returns (uint256 amountOut) {
        if (swapData.inputAmount == 0) {
            return 0;
        }
        // check whitelist for input token nd output token
        require(whitelistedTokens[inputToken], "Zapper: input token not supported");
        require(whitelistedTokens[outputToken], "Zapper: output token not supported");
        IOBRouter.swapTokenInfo memory swapTokenInfo = IOBRouter.swapTokenInfo({
            inputToken: inputToken,
            inputAmount: swapData.inputAmount,
            outputToken: outputToken,
            outputQuote: swapData.outputQuote,
            outputMin: swapData.outputMin,
            outputReceiver: receiver
        });
        return _approveRouterAndSwap(swapTokenInfo, swapData.path, swapData.executor);
    }

    // @audit -> Assumes tokens have been acquired from the user.
    function _approveRouterAndSwap(IOBRouter.swapTokenInfo memory swapTokenInfo, bytes calldata path, address executor)
    internal
    returns (uint256 amountOut)
    {
        // approve token in to swap router
        IERC20(swapTokenInfo.inputToken).safeIncreaseAllowance(address(swapRouter), swapTokenInfo.inputAmount);
        amountOut = swapRouter.swap(swapTokenInfo, path, executor, referralCode);
    }

    fallback() external payable {}

    receive() external payable {}
}
