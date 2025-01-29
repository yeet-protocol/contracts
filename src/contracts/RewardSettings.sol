// SPDX-License-Identifier: MIT
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
