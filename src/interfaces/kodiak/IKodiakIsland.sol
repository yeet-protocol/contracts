// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKodiakIsland {
    // Events
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burned(address receiver, uint256 burnAmount, uint256 amount0Out, uint256 amount1Out, uint128 liquidityBurned);
    event FeesEarned(uint256 feesEarned0, uint256 feesEarned1);
    event Minted(address receiver, uint256 mintAmount, uint256 amount0In, uint256 amount1In, uint128 liquidityMinted);
    event OwnershipTransferred(address indexed previousManager, address indexed newManager);
    event Rebalance(int24 lowerTick_, int24 upperTick_, uint128 liquidityBefore, uint128 liquidityAfter);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event UpdateManagerParams(
        uint16 managerFeeBPS,
        address managerTreasury,
        uint16 gelatoRebalanceBPS,
        uint16 gelatoSlippageBPS,
        uint32 gelatoSlippageInterval
    );

    // Functions
    function GELATO() external view returns (address payable);

    function RESTRICTED_MINT_ENABLED() external view returns (uint16);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function burn(uint256 burnAmount, address receiver)
        external
        returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function executiveRebalance(
        int24 newLowerTick,
        int24 newUpperTick,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        bool zeroForOne
    ) external;

    function gelatoRebalanceBPS() external view returns (uint16);

    function gelatoSlippageBPS() external view returns (uint16);

    function gelatoSlippageInterval() external view returns (uint32);

    function getMintAmounts(uint256 amount0Max, uint256 amount1Max)
        external
        view
        returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function getPositionID() external view returns (bytes32 positionID);

    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);

    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96)
        external
        view
        returns (uint256 amount0Current, uint256 amount1Current);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _pool,
        uint16 _managerFeeBPS,
        int24 _lowerTick,
        int24 _upperTick,
        address _manager_
    ) external;

    function kodiakBalance0() external view returns (uint256);

    function kodiakBalance1() external view returns (uint256);

    function kodiakFeeBPS() external view returns (uint16);

    function kodiakTreasury() external view returns (address);

    function lowerTick() external view returns (int24);

    function manager() external view returns (address);

    function managerBalance0() external view returns (uint256);

    function managerBalance1() external view returns (uint256);

    function managerFeeBPS() external view returns (uint16);

    function managerTreasury() external view returns (address);

    function mint(uint256 mintAmount, address receiver)
        external
        returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted);

    function name() external view returns (string memory);

    function pool() external view returns (address);

    function rebalance(
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        bool zeroForOne,
        uint256 feeAmount,
        address paymentToken
    ) external;

    function renounceOwnership() external;

    function restrictedMintToggle() external view returns (uint16);

    function symbol() external view returns (string memory);

    function toggleRestrictMint() external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function upperTick() external view returns (int24);
}
