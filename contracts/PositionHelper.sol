//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from "./structs/SharedStructs.sol";
import "hardhat/console.sol";

library PositionHelper {
    function remove(SharedStructs.Positon[] storage positions, uint256 index)
        public
    {
        require(index < positions.length, "Index overflows");

        for (uint256 i = index; i < positions.length - 1; i++) {
            positions[i] = positions[i + 1];
        }
        positions.pop();
    }
}
