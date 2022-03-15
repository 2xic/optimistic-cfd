//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library SharedStructs {
    struct Positon {
        uint256 entryPrice;
        uint256 chipQuantity;
        address owner;
    }

    struct Rebalance {
        PriceMovment direction;
        uint256 minted;
        uint256 price;
    }

    enum PositionType {
        LONG,
        SHORT,
        BYSTANDARDER
    }

    enum PriceMovment {
        DOWN,
        UP,
        STABLE
    }
}
