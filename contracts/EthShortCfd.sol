//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EthShortCfd is ERC20 {
    address public _owner;

    constructor(address owner) ERC20("EthShortCfd", "ETHSCDF") {
        _owner = owner;
    }

    function exchange(uint256 amount, address receiver)
        public
        payable
        returns (uint256)
    {
        /*
        require(
            msg.sender == _owner,
            "Only the pool contract should call this function"
        );*/
        _mint(receiver, amount);

        return amount;
    }
}
