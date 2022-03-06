//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EthShortCfd is ERC20 {
    constructor() ERC20("EthShortCfd", "ETHSCDF") {}
}
