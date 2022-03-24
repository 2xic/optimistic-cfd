//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from "../structs/SharedStructs.sol";
import "hardhat/console.sol";
import {MathHelper} from "./MathHelper.sol";

library PositionHelper {
    using MathHelper for uint256;

    function remove(SharedStructs.Position[] storage positions, uint256 index)
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
        SharedStructs.PositionType protocolPosition,
        SharedStructs.PriceMovement priceDirection,
        SharedStructs.Position[] storage longPositions,
        SharedStructs.Position[] storage shortPositions
    ) public returns (uint256) {
        bool protocolIsShortAndPriceGoesDown = protocolPosition ==
            SharedStructs.PositionType.SHORT &&
            priceDirection == SharedStructs.PriceMovement.DOWN;
        bool isProtocolInWinningPosition = protocolIsShortAndPriceGoesDown;
        uint256 padding = 100 * 100;

        for (uint256 i = 0; i < shortPositions.length; i++) {
            if (!isProtocolInWinningPosition) {
                bool isMovementWithPool = priceDirection ==
                    SharedStructs.PriceMovement.DOWN;
                uint256 adjustments = getProtocolChipAdjustment(
                    isMovementWithPool,
                    priceChange,
                    padding
                );
                shortPositions[i].chipQuantity *= adjustments;
            } else if (shortPositions[i].owner == address(this)) {
                shortPositions[i].chipQuantity *= priceChange;
            }
            shortPositions[i].chipQuantity /= padding;
        }

        for (uint256 i = 0; i < longPositions.length; i++) {
            bool isMovementWithPool = priceDirection ==
                SharedStructs.PriceMovement.UP;
            uint256 adjustments = getProtocolChipAdjustment(
                isMovementWithPool,
                priceChange,
                padding
            );

            longPositions[i].chipQuantity *= adjustments;
            longPositions[i].chipQuantity /= padding;
        }

        return 0;
    }

    function getPoolBalance(
        SharedStructs.PriceMovement priceDirection,
        SharedStructs.Position[] storage longPositions,
        SharedStructs.Position[] storage shortPositions
    ) public view returns (uint256) {
        uint256 poolBalance = 0;
        bool isPriceDown = priceDirection == SharedStructs.PriceMovement.DOWN;

        SharedStructs.Position[] storage bigPool = (
            isPriceDown ? shortPositions : longPositions
        );
        SharedStructs.Position[] storage smallPool = (
            isPriceDown ? longPositions : shortPositions
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
        bool isPriceMovement,
        bool isPriceIncrease,
        uint256 minted,
        uint256 price
    ) public pure returns (SharedStructs.Rebalance memory) {
        SharedStructs.PriceMovement direction = getPriceMovement(
            isPriceMovement,
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
        SharedStructs.Position memory position,
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

    function getPriceMovement(bool isPriceMovement, bool isPriceIncrease)
        public
        pure
        returns (SharedStructs.PriceMovement)
    {
        if (isPriceMovement) {
            return
                isPriceIncrease
                    ? SharedStructs.PriceMovement.UP
                    : SharedStructs.PriceMovement.DOWN;
        } else {
            return SharedStructs.PriceMovement.STABLE;
        }
    }

    function getProtocolChipAdjustmentBalance(
        SharedStructs.Position memory position,
        uint256 adjustment
    ) public pure returns (uint256) {
        if (adjustment < position.chipQuantity) {
            return position.chipQuantity - adjustment;
        } else {
            return 0;
        }
    }

    function getProtocolChipAdjustment(
        bool isMovementWithPool,
        uint256 priceChange,
        uint256 padding
    ) public pure returns (uint256) {
        uint256 adjustments = isMovementWithPool
            ? (priceChange + padding)
            : priceChange;

        return adjustments;
    }
}
