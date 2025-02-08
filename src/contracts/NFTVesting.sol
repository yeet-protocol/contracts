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

import "./INFTContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/// @title NFTVesting contract
/// @notice Each NFT will be able to claim a certain amount of tokens based on a linear vesting schedule
contract NFTVesting {
    using SafeERC20 for IERC20;

    /// @notice The total amount of tokens to be distributed
    uint256 immutable public  tokenAmount;
    /// @notice The total amount of NFTs in the collection
    uint256 immutable public nftAmount;
    /// @notice The time when the vesting starts
    uint256 immutable public startTime;
    /// @notice The period over which the tokens will be vested
    uint256 immutable public vestingPeriod;
    /// @notice The amount of tokens each NFT can claim
    uint256 immutable public tokenAmountPerNft;

    /// @notice The token to be distributed
    IERC20 immutable public token;
    /// @notice The NFT contract to look up the owner of the NFTs
    INFTContract immutable public nftContract;

    /// @notice The amount of tokens claimed by each NFT
    /// @dev claimed[tokenId] = amount
    mapping(uint256 => uint256) public claimed;

    event Claimed(uint256 indexed tokenId, uint256 amount);

    /// @notice The blacklisted tokenIds
    mapping(uint256 => bool) public blacklistedTokenIds;
    /// @notice Turns on the blacklist
    bool immutable public blacklistEnabled;
    /// @notice The allowed tokenIds
    mapping(uint256 => bool) public allowedTokenIds;
    /// @notice Turns on the allowed list
    bool immutable public allowedListEnabled;

    /// @notice Error emitted when a token is blacklisted
    error BlacklistedTokenId(uint256 tokenId);
    /// @notice Error emitted when a token is not allowed
    error NotAllowedTokenId(uint256 tokenId);

    constructor(
        IERC20 _token,
        INFTContract _nftContract,
        uint256 _tokenAmount,
        uint256 _nftAmount,
        uint256 _startTime,
        uint256 _vestingPeriod,
        uint256[] memory _blacklistedTokenIds,
        uint256[] memory _allowedTokenIds
    ) {
        require(_startTime >= block.timestamp, "NFTVesting: startTime should be in the future");
        require(_vestingPeriod != 0, "NFTVesting: vestingPeriod should be larger than 0");
        require(_tokenAmount != 0, "NFTVesting: _tokenAmount should be larger than 0");

        // Set up blacklist
        if (_blacklistedTokenIds.length != 0) {
            blacklistEnabled = true;
            for (uint256 i = 0; i < _blacklistedTokenIds.length; i++) {
                blacklistedTokenIds[_blacklistedTokenIds[i]] = true;
            }
        }

        // Set up allowed list
        if (_allowedTokenIds.length != 0) {
            allowedListEnabled = true;
            for (uint256 i = 0; i < _allowedTokenIds.length; i++) {
                allowedTokenIds[_allowedTokenIds[i]] = true;
            }
        }

        if (allowedListEnabled && blacklistEnabled) {
            revert("NFTVesting: can't have both blacklist and allowed list enabled");
        }

        uint256 nrOfEligibleNFTs;
        if (allowedListEnabled) {
            nrOfEligibleNFTs = _allowedTokenIds.length;
        } else if (blacklistEnabled) {
            nrOfEligibleNFTs = _nftAmount - _blacklistedTokenIds.length;
        } else {
            nrOfEligibleNFTs = _nftAmount;
        }


        token = _token;
        nftContract = _nftContract;
        tokenAmount = _tokenAmount;
        nftAmount = nrOfEligibleNFTs;
        startTime = _startTime;
        vestingPeriod = _vestingPeriod;
        tokenAmountPerNft = _tokenAmount / nrOfEligibleNFTs;
    }

    /// @notice Claim the tokens for a specific NFT
    /// @notice The caller must be the owner of the NFT
    /// @notice Will return the amount of token vested since the last claim
    /// @param tokenId The ID of the NFT
    function claim(uint256 tokenId) public {
        if (blacklistEnabled && blacklistedTokenIds[tokenId]) {
            revert BlacklistedTokenId(tokenId);
        }

        if (allowedListEnabled && !allowedTokenIds[tokenId]) {
            revert NotAllowedTokenId(tokenId);
        }

        require(nftContract.ownerOf(tokenId) == msg.sender, "NFTVesting: not the owner of the NFT");

        require(block.timestamp >= startTime, "NFTVesting: vesting period has not started yet");

        uint256 claimable = claimable(tokenId);
        require(claimable != 0, "Nothing to claim");
        require(token.balanceOf(address(this)) >= claimable, "Not enough tokens in contract");

        claimed[tokenId] += claimable;

        token.safeTransfer(msg.sender, claimable);
        emit Claimed(tokenId, claimable);
    }

    /// @notice Claim the tokens for multiple NFTs at once
    /// @param tokenIds The IDs of the NFTs
    function claimMany(uint256[] calldata tokenIds) public {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length; i++) {
            claim(tokenIds[i]);
        }
    }

    /// @notice Get the amount of tokens claimable for a specific NFT
    /// @param tokenId The ID of the NFT
    function claimable(uint256 tokenId) public view returns (uint256) {
        return _getLinearVesting(getTimePassed()) - claimed[tokenId];
    }

    /// @notice Get the amount of tokens claimable for multiple NFTs at once
    /// @param tokenIds The IDs of the NFTs
    function claimableMany(uint256[] calldata tokenIds) public view returns (uint256) {
        uint256 amountClaimable;
        uint256 length = tokenIds.length;
        for (uint256 i; i < length; i++) {
            amountClaimable += claimable(tokenIds[i]);
        }
        return amountClaimable;
    }

    /// @notice Get the amount of time that has passed since the vesting started
    function getTimePassed() public view returns (uint256) {
        return block.timestamp - startTime;
    }

    /// @notice Get the amount of tokens that have vested based on the time passed
    /// @param timePassed The amount of time that has passed
    /// @return The amount of tokens that have vested
    function _getLinearVesting(uint256 timePassed) private view returns (uint256) {
        uint256 amountVested = (tokenAmountPerNft * timePassed) / vestingPeriod;
        if (amountVested > tokenAmountPerNft) {
            return tokenAmountPerNft;
        }
        return amountVested;
    }
}
