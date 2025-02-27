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
pragma solidity ^0.8.19;

import "./interfaces/IWETH.sol";
import "./interfaces/IZapper.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IManager {
    function addManager(address _manager) external;

    function removeManager(address _manager) external;
}

contract Manager is IManager, Ownable {
    mapping(address => bool) public managers;

    constructor(address _owner, address _manager) Ownable(_owner) {
        managers[_owner] = true;
        managers[_manager] = true;
    }

    modifier onlyManager() {
        require(managers[msg.sender], "Only manager can call this function");
        _;
    }

    function addManager(address _manager) external override onlyOwner {
        require(!managers[_manager], "Manager already exists");
        require(_manager != address(0), "Invalid address");
        managers[_manager] = true;
    }

    function removeManager(address _manager) external override onlyOwner {
        require(managers[_manager], "Manager does not exist");
        require(_manager != address(0), "Invalid address");
        managers[_manager] = false;
    }
}

/// @title DiscreteStakingRewards
/// @notice A contract that allows a third party to deposit rewards, that later gets put in to a vault and rewards are distributed to the users based on their share of the total staked tokens
contract StakeV2 is Manager, ReentrancyGuard {
    /// @notice The staking token
    IERC20 public immutable stakingToken;
    IZapper public immutable zapper;
    /// @notice The WETH token, used for native zapping.
    IWETH public immutable wbera;

    /// @notice The balance of each account
    /// @dev address => balance
    mapping(address => uint256) public balanceOf;

    /// @notice The total supply of the staking token
    uint256 public totalSupply;

    /// @notice The multiplier used to calculate rewards
    uint256 private constant MULTIPLIER = 1e18;
    /// @notice The vesting period after the user starts the unstake process
    uint256 private constant VESTING_PERIOD = 10 days;
    /// @notice The index used to calculate rewards
    uint256 public rewardIndex;
    /// @notice The index of the user at his last contract interaction
    mapping(address => uint256) private rewardIndexOf;
    /// @notice The rewards earned by each account
    mapping(address => uint256) private earned;

    /// @notice The number of times an account has staked
    mapping(address => uint256) public stakedTimes;
    /// @notice The limit of staking times
    uint256 public constant STAKING_LIMIT = 30;
    /// @notice The accumulated rewards, that are later distributed when a manager calls the executeRewardDistribution function
    uint256 public accumulatedRewards;
    /// @notice The total amount of vault shares
    uint256 public totalVaultShares;

    /// @notice The struct used to store the vesting information
    struct Vesting {
        uint256 amount;
        uint256 start;
        uint256 end;
    }

    /// @notice The vestings of each account
    /// @dev address => Vesting[]
    /// @dev The array of vestings is used to allow multiple unstake processes at the same time
    mapping(address => Vesting[]) public vestings;

    event RewardDeposited(address indexed sender, uint256 amount);
    event RewardsDistributed(uint256 amount, uint256 rewardIndex);
    event RewardsDistributedToken0(uint256 amount, uint256 rewardIndex);
    event VestingStarted(address indexed addr, uint256 amount, uint256 index);
    event Stake(address indexed addr, uint256 amount);
    event Unstake(address indexed addr, uint256 amount, uint256 index);
    event RageQuit(address indexed addr, uint256 amount, uint256 amountBurned, uint256 index);
    event Claimed(address indexed addr, uint256 amount);
    event RageQuitEnabled(bool enabled);

    /// @notice The constructor of the contract
    /// @param _stakingToken The staking token
    constructor(IERC20 _stakingToken, IZapper _zapper, address owner, address initialManager, IWETH _wbera) Manager(owner, initialManager) {
        stakingToken = _stakingToken;
        zapper = _zapper;
        wbera = _wbera;
    }

    /// @notice The function used to deposit rewards
    /// @dev The rewards are accumulated and later distributed with the executeRewardDistribution function
    function depositReward() public payable {
        require(msg.value > 0, "Must send value");
        accumulatedRewards += msg.value;
        emit RewardDeposited(msg.sender, msg.value);
    }

    // called by WBERA when withdrawing
    fallback() external payable {}

    function depositWBERA(uint256 amount) external {
        wbera.withdraw(amount);
        this.depositReward{
                value: amount
            }();
    }

    /// @notice The function used to calculate the accumulated rewards that gets return by the zapper since swaps are not 100% efficient
    // @dev The function is used to calculate the rewards that are not distributed yet
    /// @return The accumulated rewards in YEET tokens
    function accumulatedDeptRewardsYeet() public view returns (uint256) {
        return stakingToken.balanceOf(address(this)) - totalSupply;
    }

    /// @notice The function used to distribute excess rewards to the vault.
    function executeRewardDistributionYeet(
        IZapper.SingleTokenSwap calldata swap,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultParams
    ) external onlyManager nonReentrant {
        uint256 accRevToken0 = accumulatedDeptRewardsYeet();
        require(accRevToken0 > 0, "No rewards to distribute");
        require(swap.inputAmount <= accRevToken0, "Insufficient rewards to distribute");

        stakingToken.approve(address(zapper), accRevToken0);
        IERC20 token0 = IKodiakVaultV1(stakingParams.kodiakVault).token0();
        IERC20 token1 = IKodiakVaultV1(stakingParams.kodiakVault).token1();

        uint256 vaultSharesMinted;
        require(
            address(token0) == address(stakingToken) || address(token1) == address(stakingToken),
            "Neither token0 nor token1 match staking token"
        );

        if (address(token0) == address(stakingToken)) {
            (, vaultSharesMinted) = zapper.zapInToken0(swap, stakingParams, vaultParams);
        } else {
            (, vaultSharesMinted) = zapper.zapInToken1(swap, stakingParams, vaultParams);
        }

        _handleVaultShares(vaultSharesMinted);
        emit RewardsDistributedToken0(accRevToken0, rewardIndex);
    }

    function executeRewardDistribution(
        IZapper.SingleTokenSwap calldata swap0,
        IZapper.SingleTokenSwap calldata swap1,
        IZapper.KodiakVaultStakingParams calldata stakingParams,
        IZapper.VaultDepositParams calldata vaultParams
    ) external onlyManager nonReentrant {
        require(accumulatedRewards > 0, "No rewards to distribute");

        // take all wrapper BERA

        uint256 amountToDistribute = accumulatedRewards;
        accumulatedRewards = 0;

        // Use Zapper to swap accumulated BERA and deposit into vault
        (uint256 _islandTokens, uint256 vaultSharesMinted) =
                            zapper.zapInNative{value: amountToDistribute}(swap0, swap1, stakingParams, vaultParams);

        _handleVaultShares(vaultSharesMinted);
        emit RewardsDistributed(amountToDistribute, rewardIndex);
    }

    /// @notice Updates total vault shares and reward index after minting new shares
    /// @dev This is an internal function used by both reward distribution methods
    /// @param vaultSharesMinted The number of vault shares that were minted
    function _handleVaultShares(uint256 vaultSharesMinted) internal {
        require(vaultSharesMinted != 0, "No vault shares minted");
        totalVaultShares += vaultSharesMinted;

        // Update reward index
        if (totalSupply > 0) {
            rewardIndex += (vaultSharesMinted * MULTIPLIER) / totalSupply;
        }
    }

    /// @notice The function used to calculate the rewards of an account
    /// @param account The account to calculate the rewards for
    function _calculateRewards(address account) private view returns (uint256) {
        uint256 shares = balanceOf[account];
        return (shares * (rewardIndex - rewardIndexOf[account])) / MULTIPLIER;
    }

    /// @notice The function used to update the rewards of an account
    /// @param account The account to update the rewards for
    function _updateRewards(address account) private {
        earned[account] += _calculateRewards(account);
        rewardIndexOf[account] = rewardIndex;
    }

    /// @notice The function used to stake tokens
    /// @param amount The amount of tokens to stake
    /// @dev updates the rewards of the account
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        _updateRewards(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);

        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Stake(msg.sender, amount);
    }

    /// @notice The function used to start the unstake process
    /// @param unStakeAmount The amount of tokens to unstake
    /// @dev The tokens are locked for the VESTING_PERIOD
    function startUnstake(uint256 unStakeAmount) external {
        require(unStakeAmount > 0, "Amount must be greater than 0");
        require(stakedTimes[msg.sender] < STAKING_LIMIT, "Amount must be less then the STAKING_LIMIT constant"); // DOS protection https://github.com/Enigma-Dark/Yeet/issues/12
        _updateRewards(msg.sender);
        uint256 amount = balanceOf[msg.sender];
        require(amount >= unStakeAmount, "Insufficient balance");

        balanceOf[msg.sender] -= unStakeAmount;
        totalSupply -= unStakeAmount;

        uint256 start = block.timestamp;
        uint256 end = start + VESTING_PERIOD;
        vestings[msg.sender].push(Vesting(unStakeAmount, start, end));
        stakedTimes[msg.sender]++;
        emit VestingStarted(msg.sender, unStakeAmount, vestings[msg.sender].length - 1);
    }

    /// @notice The function used to unstake tokens
    /// @param index The index of the vesting to unstake
    function unstake(uint256 index) external {
        require(block.timestamp >= vestings[msg.sender][index].end, "Vesting period has not ended");
        _unstake(index);
    }

    /// @notice The function used to rage quit
    /// @notice Rage quit is used to unstake before the vesting period ends, will be called in the dApp
    /// @param index The index of the vesting to unstake
    function rageQuit(uint256 index) external {
        _unstake(index);
    }

    /// @notice The function used to unstake the tokens
    /// @param index The index of the vesting to unstake
    function _unstake(uint256 index) private {
        Vesting memory vesting = vestings[msg.sender][index];

        (uint256 unlockedAmount, uint256 lockedAmount) = calculateVesting(vesting);
        require(unlockedAmount != 0, "No unlocked amount");

        stakingToken.transfer(msg.sender, unlockedAmount);
        stakingToken.transfer(address(0x000000dead), lockedAmount);
        _remove(msg.sender, index);
        if (lockedAmount > 0) {
            emit RageQuit(msg.sender, unlockedAmount, lockedAmount, index);
        } else {
            emit Unstake(msg.sender, unlockedAmount, index);
        }
        stakedTimes[msg.sender]--;
    }

    /// @notice The function used to calculate the vesting
    /// @param vesting The vesting to calculate
    /// @return unlockedAmount The amount of tokens that can be unlocked
    /// @return lockedAmount The amount of tokens that are still locked
    function calculateVesting(Vesting memory vesting) public view returns (uint256, uint256) {
        uint256 unlockedAmount;
        uint256 lockedAmount;
        uint256 halfAmount = vesting.amount / 2;
        if (block.timestamp >= vesting.end) {
            unlockedAmount = vesting.amount;
        } else if (block.timestamp >= vesting.start) {
            uint256 timePassed = block.timestamp - vesting.start;
            uint256 timeTotal = vesting.end - vesting.start;
            uint256 linearAmount = (halfAmount * timePassed) / timeTotal;
            unlockedAmount = halfAmount + linearAmount;
            lockedAmount = vesting.amount - unlockedAmount;
        } else {
            lockedAmount = vesting.amount;
        }
        return (unlockedAmount, lockedAmount);
    }

    /// @notice The function used to get the vestings of an account
    /// @notice Used to display the vestings in the dApp
    /// @param addr The account to get the vestings for
    /// @return Vesting[] The array of vestings
    function getVestings(address addr) external view returns (Vesting[] memory) {
        return vestings[addr];
    }

    function claimRewardsInNative(
        uint256 amountToWithdraw,
        IZapper.SingleTokenSwap calldata swapData0,
        IZapper.SingleTokenSwap calldata swapData1,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        IZapper.VaultRedeemParams calldata redeemParams
    ) external nonReentrant {
        _updateRewards(msg.sender);

        IZapper.VaultRedeemParams memory updatedRedeemParams = _verifyAndPrepareClaim(amountToWithdraw, redeemParams);

        IERC20(redeemParams.vault).approve(address(zapper), amountToWithdraw);
        uint256 receivedAmount =
                            zapper.zapOutNative(msg.sender, swapData0, swapData1, unstakeParams, updatedRedeemParams);

        emit Claimed(msg.sender, receivedAmount);
    }

    function claimRewardsInToken0(
        uint256 amountToWithdraw,
        IZapper.SingleTokenSwap calldata swapData,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        IZapper.VaultRedeemParams calldata redeemParams
    ) external nonReentrant {
        _updateRewards(msg.sender);

        IZapper.VaultRedeemParams memory updatedRedeemParams = _verifyAndPrepareClaim(amountToWithdraw, redeemParams);

        IERC20(redeemParams.vault).approve(address(zapper), amountToWithdraw);
        uint256 receivedAmount = zapper.zapOutToToken0(msg.sender, swapData, unstakeParams, updatedRedeemParams);

        emit Claimed(msg.sender, receivedAmount);
    }

    function claimRewardsInToken1(
        uint256 amountToWithdraw,
        IZapper.SingleTokenSwap calldata swapData,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        IZapper.VaultRedeemParams calldata redeemParams
    ) external nonReentrant {
        _updateRewards(msg.sender);

        IZapper.VaultRedeemParams memory updatedRedeemParams = _verifyAndPrepareClaim(amountToWithdraw, redeemParams);

        IERC20(redeemParams.vault).approve(address(zapper), amountToWithdraw);
        uint256 receivedAmount = zapper.zapOutToToken1(msg.sender, swapData, unstakeParams, updatedRedeemParams);

        emit Claimed(msg.sender, receivedAmount);
    }

    function claimRewardsInToken(
        uint256 amountToWithdraw,
        address outputToken,
        IZapper.SingleTokenSwap calldata swap0,
        IZapper.SingleTokenSwap calldata swap1,
        IZapper.KodiakVaultUnstakingParams calldata unstakeParams,
        IZapper.VaultRedeemParams calldata redeemParams
    ) external nonReentrant {
        _updateRewards(msg.sender);

        IZapper.VaultRedeemParams memory updatedRedeemParams = _verifyAndPrepareClaim(amountToWithdraw, redeemParams);

        IERC20(redeemParams.vault).approve(address(zapper), amountToWithdraw);
        uint256 receivedAmount =
                            zapper.zapOut(outputToken, msg.sender, swap0, swap1, unstakeParams, updatedRedeemParams);

        emit Claimed(msg.sender, receivedAmount);
    }

    /// @notice The function used to remove a vesting from the array
    /// @param addr The account to remove the vesting from
    /// @param _index The index of the vesting to remove
    function _remove(address addr, uint256 _index) private {
        Vesting[] storage arr = vestings[addr];
        require(_index < arr.length, "index out of bound");
        uint256 length = arr.length;

        for (uint256 i = _index; i < length - 1; i++) {
            arr[i] = arr[i + 1];
        }
        arr.pop();
    }

    function getRewardIndex() external view returns (uint256) {
        return rewardIndex;
    }

    /// @notice The function used to get the rewards earned by an account
    function calculateRewardsEarned(address account) external view returns (uint256) {
        return earned[account] + _calculateRewards(account);
    }

    function _verifyAndPrepareClaim(uint256 amountToClaim, IZapper.VaultRedeemParams calldata redeemParams)
    private
    returns (IZapper.VaultRedeemParams memory)
    {
        uint256 userReward = earned[msg.sender];
        require(userReward > 0, "No rewards to claim");
        require(amountToClaim <= userReward, "Amount to claim exceeds rewards earned");
        earned[msg.sender] -= amountToClaim;
        totalVaultShares -= amountToClaim;

        return IZapper.VaultRedeemParams({
            vault: redeemParams.vault,
            receiver: redeemParams.receiver,
            shares: amountToClaim,
            minAssets: redeemParams.minAssets
        });
    }
}
