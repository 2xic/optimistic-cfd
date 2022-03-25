//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from "../structs/SharedStructs.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SharedStructs} from "../structs/SharedStructs.sol";
import {MathHelper} from "./MathHelper.sol";

library SimpleRebalanceHelper {
    using MathHelper for uint256;

    function rebalancePools(
        uint256 price,
        SharedStructs.PoolState storage poolState
    ) public returns (SharedStructs.PoolState memory) {
        if (poolState.price < price) {
            uint256 relativePriceChange = MathHelper.relativeDivide(
                poolState.price,
                price
            );

            uint256 poolAdjustment = MathHelper.multiplyPercentage(
                poolState.longPoolSize,
                relativePriceChange
            ) - poolState.longPoolSize;

            poolState.longPoolSize += poolAdjustment;
            poolState.shortPoolSize -= poolAdjustment;
        }

        return poolState;
    }
}
