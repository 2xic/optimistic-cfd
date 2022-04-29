//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract RandomAddress {
    constructor(){}

    function getAddress() public view returns (address) {
        return address(this);
    }
}
