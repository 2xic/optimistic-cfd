//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

abstract contract IPriceOracle {
    function getLatestPrice() virtual external view returns(uint);
}
