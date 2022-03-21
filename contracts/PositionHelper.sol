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

    function moveChipBetweenPositions(
        uint256 priceChange,
        SharedStructs.PositionType protcolPosition,
        SharedStructs.PriceMovment priceDirection,
        SharedStructs.Positon[] storage longPositions,
        SharedStructs.Positon[] storage shortPositons
    ) public returns (uint256) {
        bool protcolIsShortAndPriceGoesDown = protcolPosition ==
            SharedStructs.PositionType.SHORT &&
            priceDirection == SharedStructs.PriceMovment.DOWN;
        bool isProtcolInWinningPosition = protcolIsShortAndPriceGoesDown;
        uint256 padding = 100 * 100;

        for (uint256 i = 0; i < shortPositons.length; i++) {
            if (!isProtcolInWinningPosition) {
                bool isMovmentWithPool = priceDirection ==
                    SharedStructs.PriceMovment.DOWN;
                if (isMovmentWithPool) {
                    shortPositons[i].chipQuantity *= priceChange + padding;
                } else {
                    shortPositons[i].chipQuantity *= priceChange;
                }
                shortPositons[i].chipQuantity /= padding;
            } else if (shortPositons[i].owner == address(this)) {
                shortPositons[i].chipQuantity *= priceChange;
                shortPositons[i].chipQuantity /= padding;
            }
        }

        for (uint256 i = 0; i < longPositions.length; i++) {
            bool isMovmentWithPool = priceDirection ==
                SharedStructs.PriceMovment.UP;
            if (isMovmentWithPool) {
                longPositions[i].chipQuantity *= priceChange + padding;
            } else {
                longPositions[i].chipQuantity *= priceChange;
            }
            longPositions[i].chipQuantity /= padding;
        }

        return 0;
    }

    function getPoolBalance(
        SharedStructs.PriceMovment priceDirection,
        SharedStructs.Positon[] storage longPositions,
        SharedStructs.Positon[] storage shortPositons
    ) public view returns (uint256) {
        uint256 poolBalance = 0;
        bool isPriceDown = priceDirection == SharedStructs.PriceMovment.DOWN;

        SharedStructs.Positon[] storage bigPool = (
            isPriceDown ? shortPositons : longPositions
        );
        SharedStructs.Positon[] storage smallPool = (
            isPriceDown ? longPositions : shortPositons
        );

        for (uint256 i = 0; i < bigPool.length; i++) {
            poolBalance += bigPool[i].chipQuantity;
        }

        for (uint256 i = 0; i < smallPool.length; i++) {
            poolBalance -= smallPool[i].chipQuantity;
        }

        return poolBalance;
    }
}
