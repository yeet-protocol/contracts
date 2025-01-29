// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPlugin {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function claimAndDistribute() external;

    function depositFor(address account, uint256 amount) external;

    function withdrawTo(address account, uint256 amount) external;

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function setGauge(address gauge) external;

    function setBribe(address bribe) external;

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getUnderlyingName() external view returns (string memory);

    function getUnderlyingSymbol() external view returns (string memory);

    function getUnderlyingAddress() external view returns (address);

    function getProtocol() external view returns (string memory);

    function getTokensInUnderlying() external view returns (address[] memory);

    function getBribeTokens() external view returns (address[] memory);

    function getUnderlyingDecimals() external view returns (uint8);

    /*----------  ERRORS ------------------------------------------------*/

    error Plugin__InvalidZeroInput();
    error Plugin__NotAuthorizedVoter();

    /*----------  EVENTS ------------------------------------------------*/

    event Plugin__Deposited(address indexed account, uint256 amount);
    event Plugin__Withdrawn(address indexed account, uint256 amount);
}
