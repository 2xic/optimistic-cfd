//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

abstract contract CfdToken {
    function exchage(uint256 amount, address receiver) virtual public returns(uint);
}
