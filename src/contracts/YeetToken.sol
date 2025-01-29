// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YeetToken is ERC20 {
    constructor() ERC20("$YEET", "YEET") {
        _mint(msg.sender, 1_000_000_000 ether);
    }
}
