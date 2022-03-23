//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from "../structs/SharedStructs.sol";
import "hardhat/console.sol";
import {MathHelper} from "./MathHelper.sol";

library PositionHelper {
    using MathHelper for uint256;

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
                uint256 adjustments = getProtolChipAdjustment(
                    isMovmentWithPool,
                    priceChange,
                    padding
                );
                shortPositons[i].chipQuantity *= adjustments;
            } else if (shortPositons[i].owner == address(this)) {
                shortPositons[i].chipQuantity *= priceChange;
            }
            shortPositons[i].chipQuantity /= padding;
        }

        for (uint256 i = 0; i < longPositions.length; i++) {
            bool isMovmentWithPool = priceDirection ==
                SharedStructs.PriceMovment.UP;
            uint256 adjustments = getProtolChipAdjustment(
                isMovmentWithPool,
                priceChange,
                padding
            );

            longPositions[i].chipQuantity *= adjustments;
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

    function getRebalance(
        bool isPriceMovment,
        bool isPriceIncrease,
        uint256 minted,
        uint256 price
    ) public pure returns (SharedStructs.Rebalance memory) {
        SharedStructs.PriceMovment direction = getPrirection(
            isPriceMovment,
            isPriceIncrease
        );

        return
            SharedStructs.Rebalance({
                direction: direction,
                minted: minted,
                price: price
            });
    }

    function calculateProfits(
        SharedStructs.Positon memory position,
        uint256 amount,
        uint256 price
    ) public pure returns (uint256) {
        uint256 entryPrice = position.entryPrice;
        uint256 priceDelta = ((entryPrice * 100 - price * 100) / entryPrice) *
            100;
        uint256 profits = ((position.entryChipQuantity - amount) * priceDelta) /
            (1000_0000);
        return profits;
    }

    function getPrirection(bool isPriceMovment, bool isPriceIncrease)
        public
        pure
        returns (SharedStructs.PriceMovment)
    {
        if (isPriceMovment) {
            return
                isPriceIncrease
                    ? SharedStructs.PriceMovment.UP
                    : SharedStructs.PriceMovment.DOWN;
        } else {
            return SharedStructs.PriceMovment.STABLE;
        }
    }

    function getProtcolChipAdjustmentBalance(
        SharedStructs.Positon memory position,
        uint256 adjustment
    ) public pure returns (uint256) {
        if (adjustment < position.chipQuantity) {
            return position.chipQuantity - adjustment;
        } else {
            return 0;
        }
    }

    function getProtolChipAdjustment(
        bool isMovmentWithPool,
        uint256 priceChange,
        uint256 padding
    ) public pure returns (uint256) {
        uint256 adjustments = isMovmentWithPool
            ? (priceChange + padding)
            : priceChange;

        return adjustments;
    }
}
