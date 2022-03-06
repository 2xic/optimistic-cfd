//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Chip is ERC20 {
    constructor() ERC20("Chip", "C") {}

    function mint(uint256 amount) public payable returns (uint256) {
        require(amount > 0, "Amount not spesificed");
        _mint(address(this), amount);
        return amount;
    }

    function burn(uint256 amount) public payable returns (uint256) {
        require(amount > 0, "Amount not spesificed");
        _burn(address(this), amount);
        return amount;
    }
}
