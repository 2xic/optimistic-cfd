//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from "../structs/SharedStructs.sol";
import "hardhat/console.sol";
import {PositionHelper} from "./PositionHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library RebalancePoolHelper {
    using PositionHelper for SharedStructs.Positon[];

    function rebalancePools(
        uint256 price,
        uint256 lastPrice,
        SharedStructs.PositionType protcolPosition,
        SharedStructs.Positon[] storage longPositions,
        SharedStructs.Positon[] storage shortPositons
    ) public returns (SharedStructs.Rebalance memory) {
        bool isPriceIncrease = lastPrice < price;
        bool isPriceDecrease = lastPrice > price;

        uint256 minted = 0;

        if (isPriceIncrease) {
            uint256 delta = ((price * 100 - lastPrice * 100) / lastPrice) * 100;

            minted = _positionChipAdjustments(
                protcolPosition,
                longPositions,
                shortPositons,
                delta,
                SharedStructs.PriceMovment.UP
            );
        } else if (isPriceDecrease) {
            uint256 delta = ((lastPrice * 100 - price * 100) / lastPrice) * 100;

            minted = _positionChipAdjustments(
                protcolPosition,
                longPositions,
                shortPositons,
                delta,
                SharedStructs.PriceMovment.DOWN
            );
        }

        bool isPriceMovment = isPriceIncrease || isPriceDecrease;

        return
            PositionHelper.getRebalance(
                isPriceMovment,
                isPriceIncrease,
                minted,
                price
            );
    }

    function rebalanceProtocolExposoure(
        SharedStructs.Positon memory position,
        uint256 amount,
        uint256 price,
        uint256 adjustment,
        IERC20 chipToken,
        address tresuaryAddress,
        bool isProtcolLong
    ) public returns (SharedStructs.Positon memory ) {
       // uint256 adjustment = amount * expontent;

        if (price == position.entryPrice) {
            position.chipQuantity -= adjustment;
        } else if (amount <= position.entryChipQuantity) {
            bool hasShortProfits = !isProtcolLong &&
                price < position.entryPrice;

            if (hasShortProfits) {
                uint256 profits = PositionHelper.calculateProfits(
                    position,
                    amount,
                    price
                );
                chipToken.approve(address(this), profits);
                chipToken.transferFrom(
                    address(this),
                    tresuaryAddress, //address(tresuary),
                    profits
                );

                uint256 newBalance = PositionHelper
                    .getProtcolChipAdjustmentBalance(
                        position,
                        adjustment
                    );
                position.chipQuantity = newBalance;
                position.entryChipQuantity = newBalance;
            } else {
                require(false, "Not implemented");
            }
        }

        return position;
    }

    function _positionChipAdjustments(
        SharedStructs.PositionType protcolPosition,
        SharedStructs.Positon[] storage longPositions,
        SharedStructs.Positon[] storage shortPositons,
        uint256 priceChange,
        SharedStructs.PriceMovment direction
    ) public returns (uint256) {
        PositionHelper.moveChipBetweenPositions(
            priceChange,
            protcolPosition,
            direction,
            longPositions,
            shortPositons
        );
        uint256 poolBalance = PositionHelper.getPoolBalance(
            direction,
            longPositions,
            shortPositons
        );
        return poolBalance;
    }
}
