//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Chip is ERC20 {
    address public coreContract;

    constructor(
        address _coreContract
    ) ERC20("Chip", "C") {
        coreContract = _coreContract;
    }

    function mint(uint256 amount) public payable returns (uint256) {
        require(amount > 0, "Amount not spesificed");
        _mint(coreContract, amount);
        return amount;
    }

    function burn(uint256 amount) public payable returns (uint256) {
        require(amount > 0, "Amount not spesificed");
        _burn(coreContract, amount);
        return amount;
    }

    function transferToken(uint256 amount, address target) public payable returns (uint256) {
        transfer(target, amount);
        return amount;
    }
}
