// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface INFTContract {
    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function transfer(address to, uint256 tokenId) external;
}
