// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface ICommunalFarm {
    struct LockedStake {
        bytes32 kek_id;
        uint256 start_timestamp;
        uint256 liquidity;
        uint256 ending_timestamp;
        uint256 lock_multiplier;
    }

    function stakingToken() external view returns (address);

    function stakingTokenCap() external view returns (uint256);

    function kdk() external view returns (address);

    function xKdk() external view returns (address);

    function xKdkPercentage() external view returns (uint256);

    function periodFinish() external view returns (uint256);

    function lastUpdateTime() external view returns (uint256);

    function lock_max_multiplier() external view returns (uint256);

    function lock_time_for_max_multiplier() external view returns (uint256);

    function lock_time_min() external view returns (uint256);

    function rewardManagers(address) external view returns (address);

    function rewardTokens(uint256) external view returns (address);

    function rewardRates(uint256) external view returns (uint256);

    function rewardSymbols(uint256) external view returns (string memory);

    function rewardTokenAddrToIdx(address) external view returns (uint256);

    function rewardsDuration() external view returns (uint256);

    function greylist(address) external view returns (bool);

    function stakesUnlocked() external view returns (bool);

    function withdrawalsPaused() external view returns (bool);

    function rewardsCollectionPaused() external view returns (bool);

    function stakingPaused() external view returns (bool);

    function totalLiquidityLocked() external view returns (uint256);

    function lockedLiquidityOf(address account) external view returns (uint256);

    function totalCombinedWeight() external view returns (uint256);

    function combinedWeightOf(address account) external view returns (uint256);

    function calcCurCombinedWeight(address account)
        external
        view
        returns (uint256 old_combined_weight, uint256 new_combined_weight);

    function lockedStakesOf(address account) external view returns (LockedStake[] memory);

    function getRewardSymbols() external view returns (string[] memory);

    function getAllRewardTokens() external view returns (address[] memory);

    function getAllRewardRates() external view returns (uint256[] memory);

    function lockMultiplier(uint256 secs) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256[] memory rewards_per_duration_arr);

    function isTokenManagerFor(address caller_addr, address reward_token_addr) external view returns (bool);

    function stakeLocked(uint256 liquidity, uint256 secs) external;

    function withdrawLocked(bytes32 kek_id) external;

    function withdrawLockedMultiple(bytes32[] memory kek_ids) external;

    function withdrawLockedAll() external;

    function emergencyWithdraw(bytes32 kek_id) external;

    function getReward() external returns (uint256[] memory);

    function sync() external;

    event StakeLocked(address indexed user, uint256 amount, uint256 secs, bytes32 kek_id, address source_address);
    event WithdrawLocked(address indexed user, uint256 amount, bytes32 kek_id, address destination_address);
    event RewardPaid(address indexed user, uint256 reward, address token_address, address destination_address);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address destination_address, address token, uint256 amount);
    event RewardsPeriodRenewed(address token);
    event LockedStakeMaxMultiplierUpdated(uint256 multiplier);
    event LockedStakeTimeForMaxMultiplier(uint256 secs);
    event LockedStakeMinTime(uint256 secs);
    event RewardTokenAdded(address rewardToken);
    event xKdkPercentageUpdated(uint256 xKdkPercentage);
    event StakingTokenCapUpdated(uint256 stakingTokenCap);
}
