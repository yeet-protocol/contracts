// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPlugin} from "../../src/interfaces/beradrome/IPlugin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

contract BeradromeFarmMock is IPlugin {
    IERC20 public token;
    uint256 public totalAssets;
    mapping(address => uint256) public balances;

    constructor(address _token) {
        token = IERC20(_token);
    }

    /*----------  FUNCTIONS  --------------------------------------------*/
    function claimAndDistribute() external {}

    function depositFor(address account, uint256 amount) external {
        totalAssets += amount;
        balances[account] += amount;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Plugin__Deposited(account, amount);
    }

    function withdrawTo(address account, uint256 amount) external {
        totalAssets -= amount;
        balances[msg.sender] -= amount;
        IERC20(token).transfer(account, amount);
        emit Plugin__Withdrawn(account, amount);
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function setGauge(address gauge) external {}

    function setBribe(address bribe) external {}

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return IERC20(token).totalSupply();
    }

    function getUnderlyingName() external view returns (string memory) {}

    function getUnderlyingSymbol() external view returns (string memory) {}

    function getUnderlyingAddress() external view returns (address) {
        return address(token);
    }

    function getProtocol() external view returns (string memory) {}

    function getTokensInUnderlying() external view returns (address[] memory) {}

    function getBribeTokens() external view returns (address[] memory) {}

    function getUnderlyingDecimals() external view returns (uint8) {}
}
