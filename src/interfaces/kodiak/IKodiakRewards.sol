// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKodiakRewards {
    function distributedTokensLength() external view returns (uint256);

    function distributedToken(uint256 index) external view returns (address);

    function isDistributedToken(address token) external view returns (bool);

    function addRewardsToPending(address token, uint256 amount) external;

    function harvestAllRewards() external;

    function harvestRewards(address token) external;

    function pendingRewardsAmount(address token, address userAddress) external view returns (uint256);
}
