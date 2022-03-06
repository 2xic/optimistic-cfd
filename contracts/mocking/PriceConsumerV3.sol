//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    function getLatestPrice() public pure override returns (uint256) {
        return 5;
    }
}
