//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CfdToken is ERC20 {
    address public owner;

    constructor(address _owner) ERC20("Cfd", "CFD") {
        owner = _owner;
    }
}
