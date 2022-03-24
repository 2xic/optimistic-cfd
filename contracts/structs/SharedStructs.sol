//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library SharedStructs {
    struct Position {
        uint256 entryPrice;
        uint256 entryChipQuantity;
        uint256 chipQuantity;
        address owner;
    }

    struct Rebalance {
        PriceMovement direction;
        uint256 minted;
        uint256 price;
    }

    enum PositionType {
        LONG,
        SHORT,
        BYSTANDER
    }

    enum PriceMovement {
        DOWN,
        UP,
        STABLE
    }
}
