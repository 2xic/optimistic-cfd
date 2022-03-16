//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EthLongCfd is ERC20 {
    address private owner;

    constructor(address _owner) ERC20("EthLongCfd", "ETHLCDF") {
        owner = _owner;
    }

    function exchange(uint256 amount, address receiver)
        public
        payable
        returns (uint256)
    {
        require(
            msg.sender == owner,
            "Only the owner contract should call this function"
        );
        _mint(receiver, amount);

        return amount;
    }

    function transferOwnerShip(address newOwner) public payable returns (bool) {
        require(
            msg.sender == owner,
            "Only the owner contract should call this function"
        );
        owner = newOwner;        

        return true;
    }
}
