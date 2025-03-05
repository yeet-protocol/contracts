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

import {INFTContract} from "src/INFTContract.sol";

contract MockNFTContract is INFTContract {
    mapping(address => uint256) public _balanceOf;
    mapping(uint256 => address) public _ownerOf;
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor() {}

    function mint(address to, uint256 tokenId) public {
        _balanceOf[to] = _balanceOf[to] + 1;
        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function mintAmount(address to, uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            mint(to, i);
        }
    }

    function burn(address from, uint256 tokenId) public {
        _balanceOf[from] = _balanceOf[from] - 1;
        _ownerOf[tokenId] = address(0);
        emit Transfer(from, address(0), tokenId);
    }

    function transfer(address to, uint256 tokenId) external override {
        address from = _ownerOf[tokenId];
        _balanceOf[from] = _balanceOf[from] - 1;
        _balanceOf[to] = _balanceOf[to] + 1;
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function balanceOf(address owner) external view override returns (uint256) {
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        return _ownerOf[tokenId];
    }

    function test() public {}
}
