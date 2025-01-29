// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGauge {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;

    function notifyRewardAmount(address token, uint256 amount) external;

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(address account, uint256 amount) external;

    function _withdraw(address account, uint256 amount) external;

    function addReward(address rewardToken) external;

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function rewardPerToken(address reward) external view returns (uint256);

    function getRewardForDuration(address reward) external view returns (uint256);

    function earned(address account, address reward) external view returns (uint256);

    function left(address token) external view returns (uint256);

    function getRewardTokens() external view returns (address[] memory);
}
