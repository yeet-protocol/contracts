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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "interfaces/IMoneyBrinter.sol";
import "interfaces/beradrome/IPlugin.sol";
import "interfaces/beradrome/IGauge.sol";
import "interfaces/kodiak/IKodiakRewards.sol";
import "interfaces/kodiak/IXKdkTokenUsage.sol";
import "interfaces/kodiak/IXKdkToken.sol";
import "interfaces/IZapper.sol";

// import "forge-std/console.sol";

// Openzeppelin's fee behaviour https://docs.openzeppelin.com/contracts/5.x/erc4626#fees

/**
 * @title MoneyBrinter
 * @dev A modified ERC4626 vault.
 * Allows users to deposit underlying tokens[Kodiak Island Tokens], stake them on Beradrome Farm and compound rewards.
 * The vault charges a configurable fee on withdrawals.
 * Rewards can be harvested by anyone.
 * xKDK Rewards can be optionally allocated to Kodiak Rewards Module to harvest more rewards.
 * While compounding, the vault zaps in using the zapper to get island tokens(underling vault asset) and reinvests that into the beradrome farm.
 * The zapper swaps the reward tokens for wBera and Yeet, then mints island tokens and sends them to the vault. It also returns any unused yeet and Wbera to the vault.
 */
contract MoneyBrinter is ERC4626, IMoneyBrinter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /**
     * @notice Constant for basis point calculations
     * @return The scale factor for basis points (10000)
     */
    uint256 public immutable _BASIS_POINT_SCALE = 1e4;
    /**
     * @notice Maximum allowed fee in basis points
     * @return The maximum fee that can be set, in basis points
     */
    uint256 public immutable maxAllowedFeeBps;

    /**
     * @notice Flag to determine if xKDK should be allocated to Kodiak Rewards
     */
    bool public allocateXKDKToKodiakRewards;

    /**
     * @notice Interface for the Beradrome Farm Plugin
     */
    IPlugin public beradromeFarmPlugin;

    /**
     * @notice Interface for the Beradrome Farm Rewards Gauge
     */
    IGauge public beradromeFarmRewardsGauge;

    /**
     * @notice Address of the Kodiak Rewards contract
     */
    address public kodiakRewards;

    /**
     * @notice Address of the xKDK token contract
     */
    address public xKdk;

    /**
     * @notice Interface for the Zapper contract
     */
    IZapper public zapper;

    /**
     * @notice Address of the treasury
     */
    address public treasury;

    /**
     * @notice Exit fee in basis points
     */
    uint256 public exitFeeBasisPoints = 0;

    /**
     * @notice Mapping to store strategy manager addresses
     */
    mapping(address => bool) public strategyManager;

    // Example for Fee in BPS. 1 = 0.01% fee, 100 = 1% fee and max 1e4 = 100%

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _treasury,
        address _beradromeFarmPlugin,
        address _beradromeFarmRewardsGauge,
        uint256 _maxAllowedFeeBps
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) Ownable(_msgSender()) {
        require(_beradromeFarmPlugin != address(0), "MoneyBrinter: beradromeFarmPlugin zero address");
        require(_beradromeFarmRewardsGauge != address(0), "MoneyBrinter: beradromeFarmRewardsGauge zero address");
        require(_maxAllowedFeeBps <= _BASIS_POINT_SCALE, "MoneyBrinter: invalid max allowed fee BPS");
        maxAllowedFeeBps = _maxAllowedFeeBps;
        treasury = _treasury;
        beradromeFarmPlugin = IPlugin(_beradromeFarmPlugin);
        beradromeFarmRewardsGauge = IGauge(_beradromeFarmRewardsGauge);
    }

    modifier onlyStrategyManager() {
        require(strategyManager[_msgSender()], "MoneyBrinter: not compound manager");
        _;
    }

    // Public functions

    // === ERC4626 Public overrides ===
    function totalAssets() public view override(IMoneyBrinter, ERC4626) returns (uint256 _totalAssets) {
        _totalAssets = IPlugin(beradromeFarmPlugin).balanceOf(address(this));
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 fee = _feeOnRaw(assets, exitFeeBasisPoints);
        return super.previewWithdraw(assets + fee);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, exitFeeBasisPoints);
    }

    /**
     * @notice Harvests rewards from Kodiak rewards contract
     * @param previousKodiakRewardTokens Array of addresses of previous Kodiak reward tokens
     * @dev This function is non-reentrant and can be called by anyone
     * @dev It harvests all current rewards and any rewards from previous reward tokens
     * @dev Emits a KodiakRewardsHarvested event
     */
    function harvestKodiakRewards(address[] calldata previousKodiakRewardTokens) public override nonReentrant {
        IKodiakRewards(kodiakRewards).harvestAllRewards();
        // Kodiak rewards for previous reward tokens
        for (uint256 i = 0; i < previousKodiakRewardTokens.length; i++) {
            IKodiakRewards(kodiakRewards).harvestRewards(previousKodiakRewardTokens[i]);
        }
        emit KodiakRewardsHarvested(_msgSender(), previousKodiakRewardTokens);
    }

    /**
     * @notice Harvests rewards from Beradrome farm
     * @dev This function is non-reentrant and can be called by anyone
     * @dev It claims Beradrome rewards and optionally allocates xKDK to the Kodiak rewards module
     * @dev Emits a BeradromeRewardsHarvested event
     */
    function harvestBeradromeRewards() public override nonReentrant {
        beradromeFarmRewardsGauge.getReward(address(this)); // claims Beradrome rewards
        // allocate xKDK to token rewards module.
        if (allocateXKDKToKodiakRewards) {
            uint256 xKdkBalance = IXKdkToken(xKdk).balanceOf(address(this));
            IXKdkToken(xKdk).approveUsage(kodiakRewards, xKdkBalance); // approve xKDK to be used by Token Rewards Module
            IXKdkTokenUsage(xKdk).allocate(
                kodiakRewards, xKdkBalance, "" /* calldata unused in Token Rewards Module */
            );
        }
        emit BeradromeRewardsHarvested(_msgSender());
    }

    /**
     * @notice Compounds rewards by swapping harvested tokens, staking in Kodiak vault and depositing into Beradrome farm
     * @param swapInputTokens Array of input token addresses for swaps
     * @param swapToToken0 Array of swap params to swap input tokens to token0
     * @param swapToToken1 Array of swap params to swap input tokens to token1
     * @param stakingParams Parameters for staking in Kodiak vault
     * @param vaultStakingParams Parameters for depositing into vault
     * @return uint256 Amount of island tokens minted
     * @dev This function is non-reentrant and can only be called by the strategy manager
     * @dev It approves tokens, performs swaps, stakes in Kodiak vault, and deposits into farm
     * @dev Emits a VaultCompounded event
     */
    function compound(
        address[] calldata swapInputTokens,
        IZapper.SingleTokenSwap[] calldata swapToToken0,
        IZapper.SingleTokenSwap[] calldata swapToToken1,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultStakingParams
    ) public override onlyStrategyManager nonReentrant returns (uint256) {
        // By adding the staking params receiver as the vault address, we ensure that zapper returns the island Tokens to the vault
        require(stakingParams.receiver == address(this), "Invalid staking receiver");
        require(swapInputTokens.length == swapToToken0.length + swapToToken1.length, "Invalid swap data");
        uint256 initialSupply = totalSupply();
        uint256 shareValueBefore = previewRedeem(initialSupply);
        _approveTokens(swapInputTokens, swapToToken0, swapToToken1);
        IZapper.MultiSwapParams memory swapParams = IZapper.MultiSwapParams({
            inputTokens: swapInputTokens,
            swapToToken0: swapToToken0,
            swapToToken1: swapToToken1
        });
        (uint256 islandTokensMinted, uint256 vaultSharesMinted) =
            zapper.zapInWithMultipleTokens(swapParams, stakingParams, vaultStakingParams);
        require(vaultSharesMinted == 0, "MoneyBrinter: vault shares minted while compounding");
        require(islandTokensMinted >= stakingParams.amountSharesMin, "MoneyBrinter: not enough island tokens minted");
        // deposit into farm
        emit VaultCompounded(_msgSender(), islandTokensMinted);
        _depositIntoFarm(islandTokensMinted);
        uint256 shareValueAfter = previewRedeem(initialSupply);
        require(shareValueAfter >= shareValueBefore, "MoneyBrinter: Bad Compound");
        return islandTokensMinted;
    }

    // Admin Functions
    /**
     * @notice Sets the exit fee in basis points
     * @param newFeeBps The new exit fee in basis points
     * @dev Can only be called by the owner
     * @dev Emits ExitFeeBasisPointsSet event
     */
    function setExitFeeBasisPoints(uint256 newFeeBps) public override onlyOwner {
        require(newFeeBps <= maxAllowedFeeBps, "MoneyBrinter: feeBps too high");
        uint256 oldFeeBps = exitFeeBasisPoints;
        exitFeeBasisPoints = newFeeBps;
        emit ExitFeeBasisPointsSet(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Sets the treasury address
     * @param newTreasury The new treasury address
     * @dev Can only be called by the owner
     * @dev Emits TreasuryUpdated event
     */
    function setTreasury(address newTreasury) public override onlyOwner {
        require(newTreasury != address(0), "MoneyBrinter: treasury cannot be zero address");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Sets the zapper contract address
     * @param newZapper The new zapper contract address
     * @dev Can only be called by the owner
     * @dev Emits ZapperUpdated event
     */
    function setZapper(address newZapper) public override onlyOwner {
        require(newZapper != address(0), "MoneyBrinter: zapper cannot be zero address");
        address oldZapper = address(zapper);
        zapper = IZapper(newZapper);
        emit ZapperUpdated(oldZapper, newZapper);
    }

    /**
     * @notice Sets or unsets an address as a strategy manager
     * @param manager The address to set or unset as a strategy manager
     * @param isWhitelisted True to set as strategy manager, false to unset
     * @dev Can only be called by the owner
     * @dev Emits StrategyManagerUpdated event
     */
    function setStrategyManager(address manager, bool isWhitelisted) public override onlyOwner {
        strategyManager[manager] = isWhitelisted;
        emit StrategyManagerUpdated(manager, isWhitelisted);
    }

    /**
     * @notice Sets the xKDK token address
     * @param newXKdk The new xKDK token address
     * @dev Can only be called by the owner
     * @dev Emits XKdkUpdated event
     */
    function setXKdk(address newXKdk) public override onlyOwner {
        require(newXKdk != address(0), "MoneyBrinter: xKdk cannot be zero address");
        address oldXKdk = xKdk;
        xKdk = newXKdk;
        emit XKdkUpdated(oldXKdk, newXKdk);
    }

    /**
     * @notice Sets the flag for allocating xKDK to Kodiak rewards
     * @param flag True to allocate xKDK to Kodiak rewards, false otherwise
     * @dev Can only be called by the owner
     * @dev Emits xKDKAllocationFlagUpdated event
     */
    function setAllocationFlagxKDK(bool flag) public override onlyOwner {
        bool oldFlag = allocateXKDKToKodiakRewards;
        allocateXKDKToKodiakRewards = flag;
        emit xKDKAllocationFlagUpdated(oldFlag, flag);
    }

    /**
     * @notice Sets the Kodiak rewards address
     * @param newKodiakRewards The new Kodiak rewards address
     * @dev Can only be called by the owner
     * @dev Emits KodiakRewardsUpdated event
     */
    function setKodiakRewards(address newKodiakRewards) public override onlyOwner {
        require(newKodiakRewards != address(0), "MoneyBrinter: kodiakRewards cannot be zero address");
        address oldKodiakRewards = kodiakRewards;
        kodiakRewards = newKodiakRewards;
        emit KodiakRewardsUpdated(oldKodiakRewards, newKodiakRewards);
    }

    /**
     * @notice Deallocates xKDK from Kodiak rewards
     * @param amount The amount of xKDK to deallocate
     * @dev Can only be called by the strategy manager
     * @dev Emits XKDKDeallocated event
     */
    function deallocateXKDK(uint256 amount) public override onlyStrategyManager {
        IXKdkTokenUsage(xKdk).deallocate(kodiakRewards, amount, "");
    }

    /**
     * @notice Initiates redeeming of xKDK
     * @param amount The amount of xKDK to redeem
     * @param duration The duration for redeeming
     * @dev Can only be called by the strategy manager
     */
    function initiateRedeem(uint256 amount, uint256 duration) public override onlyStrategyManager {
        (bool success,) = xKdk.call(abi.encodeWithSignature("redeem(uint256,uint256)", amount, duration));
        require(success, "MoneyBrinter: redeem failed");
    }

    /**
     * @notice Finalizes redeeming of xKDK
     * @param redeemIndex The index of the redeem entry to finalize
     * @dev Can only be called by the strategy manager
     */
    function finalizeRedeem(uint256 redeemIndex) public override onlyStrategyManager {
        (bool success,) = xKdk.call(abi.encodeWithSignature("finalizeRedeem(uint256)", redeemIndex));
        require(success, "MoneyBrinter: finalizeRedeem failed");
    }

    /**
     * @notice Updates the rewards address for ongoing redeem processes
     * @param redeemIndex The index of the redeem entry to update
     * @dev Can only be called by the strategy manager
     */
    function updateRedeemRewardsAddress(uint256 redeemIndex) public override onlyStrategyManager {
        (bool success,) = xKdk.call(abi.encodeWithSignature("updateRedeemRewardsAddress(uint256)", redeemIndex));
        require(success, "MoneyBrinter: updateRedeemRewardsAddress failed");
    }

    /**
     * @notice Cancels an ongoing redeem process
     * @param redeemIndex The index of the redeem entry to cancel
     * @dev Can only be called by the strategy manager
     * @dev Emits RedeemCancelled event
     */
    function cancelRedeem(uint256 redeemIndex) public override onlyStrategyManager {
        (bool success,) = xKdk.call(abi.encodeWithSignature("cancelRedeem(uint256)", redeemIndex));
        require(success, "MoneyBrinter: cancelRedeem failed");
    }

    // ######## Internal Functions ########

    function _approveTokens(
        address[] calldata inputTokens,
        IZapper.SingleTokenSwap[] calldata swapData0,
        IZapper.SingleTokenSwap[] calldata swapData1
    ) private {
        for (uint256 i = 0; i < swapData0.length; i++) {
            IERC20(inputTokens[i]).safeIncreaseAllowance(address(zapper), swapData0[i].inputAmount);
        }
        for (uint256 i = swapData0.length; i < inputTokens.length; i++) {
            IERC20(inputTokens[i]).safeIncreaseAllowance(address(zapper), swapData1[i - swapData0.length].inputAmount);
        }
    }

    // === Fee operations ===

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) private pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }

    // === Staking Integration operations ===

    function _depositIntoFarm(uint256 assets) internal {
        // approve Beradrome farm
        IERC20(asset()).safeIncreaseAllowance(address(beradromeFarmPlugin), assets);
        // deposit assets into Beradrome farm
        beradromeFarmPlugin.depositFor(address(this), assets);
    }

    function _withdrawFromFarm(uint256 assets) internal {
        // withdraw assets from Beradrome farm
        beradromeFarmPlugin.withdrawTo(address(this), assets);
    }

    // === ERC4626 internal overrides ===

    function _withdraw(address caller, address receiver, address assetOwner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (caller != assetOwner) {
            _spendAllowance(assetOwner, caller, shares);
        }
        uint256 fee = _feeOnRaw(assets, exitFeeBasisPoints);
        _burn(assetOwner, shares);
        _withdrawFromFarm(assets + fee);
        if (fee > 0) {
            // @todo add event emit
            IERC20(address(asset())).safeTransfer(treasury, fee);
            emit FeeCollected(caller, assetOwner, treasury, fee);
        }
        IERC20(address(asset())).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, assetOwner, assets, shares);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        IERC20(address(asset())).safeTransferFrom(caller, address(this), assets);
        // deposit into Beradrome farm
        _depositIntoFarm(assets); // slightly dilutes unclaimed rewards. Can be used to frontrun rewards
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _decimalsOffset() internal view override returns (uint8) {
        return 5;
    }
}
