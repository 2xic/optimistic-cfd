//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {EthLongCfd} from "./tokens/EthLongCfd.sol";
import {EthShortCfd} from "./tokens/EthShortCfd.sol";
import {Treasury} from "./Treasury.sol";
import {Chip} from "./tokens/Chip.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SharedStructs} from "./structs/SharedStructs.sol";
import {PositionHelper} from "./helpers/PositionHelper.sol";
import { RebalancePoolHelper } from "./helpers/RebalancePoolHelper.sol";

contract Pool {
    using PositionHelper for SharedStructs.Positon[];
    using RebalancePoolHelper for SharedStructs.Positon[];

    SharedStructs.Positon[] public longPositions;
    SharedStructs.Positon[] public shortPositons;
    SharedStructs.PositionType public protcolPosition;

    IPriceOracle private priceOracle;
    IERC20 private chipToken;
    EthLongCfd private longCfd;
    EthShortCfd private shortCfd;
    Treasury private tresuary;

    bool private isInitalized;
    uint256 private lastPrice;
    uint16 private expontent;

    constructor(
        address _priceFeed,
        address _chipToken,
        address _longTCfd,
        address _shortCfd,
        address _tresuary
    ) {
        priceOracle = IPriceOracle(_priceFeed);
        longCfd = EthLongCfd(_longTCfd);
        shortCfd = EthShortCfd(_shortCfd);
        chipToken = IERC20(_chipToken);
        tresuary = Treasury(_tresuary);
        expontent = 1000;
        isInitalized = false;
    }

    function init(uint256 amount, SharedStructs.PositionType position)
        public
        payable
        returns (bool)
    {
        require(!isInitalized, "Init should only be called once");

        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);
        lastPrice = price;
        isInitalized = true;

        if (position == SharedStructs.PositionType.LONG) {
            require(
                chipToken.transferFrom(msg.sender, address(this), deposited),
                "Transfer of chip token failed"
            );
            _createPosition(
                SharedStructs.PositionType.LONG,
                price,
                deposited,
                msg.sender
            );
            _createPosition(
                SharedStructs.PositionType.SHORT,
                price,
                deposited,
                address(this)
            );
            protcolPosition = SharedStructs.PositionType.SHORT;
        } else if (position == SharedStructs.PositionType.SHORT) {
            require(
                chipToken.transferFrom(msg.sender, address(this), deposited),
                "Transfer of chip token failed"
            );
            _createPosition(
                SharedStructs.PositionType.SHORT,
                price,
                deposited,
                msg.sender
            );
            _createPosition(
                SharedStructs.PositionType.LONG,
                price,
                deposited,
                address(this)
            );
            protcolPosition = SharedStructs.PositionType.LONG;
        }
        return true;
    }

    function enter(uint256 amount, SharedStructs.PositionType position)
        public
        payable
        returns (bool)
    {
        require(isInitalized, "call init before enter");

        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);

        bool isOverwritingProtcol = position == protcolPosition;

        if (isOverwritingProtcol) {
            _createPosition(position, price, deposited, msg.sender);
            _readjuceProtcolPosition(deposited, price);
        } else {
            require(false, "not implemented");
        }
        return true;
    }

    function getUserBalance(address user) public view returns (uint256) {
        uint256 balance = 0;
        for (uint256 i = 0; i < longPositions.length; i++) {
            if (longPositions[i].owner == user) {
                balance += longPositions[i].chipQuantity;
            }
        }

        for (uint256 i = 0; i < shortPositons.length; i++) {
            if (shortPositons[i].owner == user) {
                balance += shortPositons[i].chipQuantity;
            }
        }

        return balance;
    }

    function update() public payable returns (bool) {
        SharedStructs.Rebalance memory rebalance = rebalancePools();
        bool priceMovedAgainstProtcolLong = (protcolPosition ==
            SharedStructs.PositionType.LONG &&
            rebalance.direction == SharedStructs.PriceMovment.DOWN);
        bool priceMovedAgainstProtcoShort = (protcolPosition ==
            SharedStructs.PositionType.SHORT &&
            rebalance.direction == SharedStructs.PriceMovment.UP);

        if (priceMovedAgainstProtcolLong) {
            // protcol has to "mint" new tokens now.
            // currently just "fake" mints, but this will be changed as new tests are implemented
            longPositions.push(
                SharedStructs.Positon({
                    entryChipQuantity: rebalance.minted,
                    entryPrice: rebalance.price,
                    chipQuantity: rebalance.minted,
                    owner: address(this)
                })
            );
        } else if (priceMovedAgainstProtcoShort) {
            shortPositons.push(
                SharedStructs.Positon({
                    entryChipQuantity: rebalance.minted,
                    entryPrice: rebalance.price,
                    chipQuantity: rebalance.minted,
                    owner: address(this)
                })
            );
        }

        return true;
    }

    function rebalancePools()
        public
        payable
        returns (SharedStructs.Rebalance memory)
    {
        uint256 price = priceOracle.getLatestPrice();

        uint256 currentPrice = price;
        uint256 oldPrice = lastPrice;

        lastPrice = price;

        return RebalancePoolHelper.rebalancePools(
            currentPrice,
            oldPrice,
            protcolPosition,
            longPositions,
            shortPositons
        );

        
    }

    function _createPosition(
        SharedStructs.PositionType position,
        uint256 price,
        uint256 deposited,
        address owner
    ) private returns (uint256) {
        uint256 mintedTokens = deposited / price;
        SharedStructs.Positon memory postion = SharedStructs.Positon({
            entryPrice: price,
            entryChipQuantity: deposited * expontent,
            chipQuantity: deposited * expontent,
            owner: owner
        });

        if (position == SharedStructs.PositionType.LONG) {
            longCfd.exchange(mintedTokens, owner);
            longPositions.push(postion);
        } else if (position == SharedStructs.PositionType.SHORT) {
            shortCfd.exchange(mintedTokens, owner);
            shortPositons.push(postion);
        }
        return 0;
    }

    function _readjuceProtcolPosition(uint256 amount, uint256 price)
        private
        returns (bool)
    {
        bool isProtcolLong = protcolPosition == SharedStructs.PositionType.LONG;
        SharedStructs.Positon[] storage protcolPositionsPool = (
            isProtcolLong ? longPositions : shortPositons
        );

        for (uint256 i = 0; i < protcolPositionsPool.length; i++) {
            bool isProtcol = protcolPositionsPool[i].owner == address(this);

            if (isProtcol) {
                protcolPositionsPool[i] = RebalancePoolHelper.rebalanceProtocolExposoure(
                    protcolPositionsPool[i],
                    amount,
                    price,
                    amount * expontent,
                    chipToken,
                    address(tresuary),
                    isProtcolLong
                );

                if (protcolPositionsPool[i].chipQuantity == 0) {
                    protcolPositionsPool.remove(i);
                }
            }
        }

        uint256 poolBalance = PositionHelper.getPoolBalance(
            SharedStructs.PriceMovment.DOWN,
            longPositions,
            shortPositons
        );
        bool protcolHasToCreatePostiion = 0 < poolBalance;

        if (protcolHasToCreatePostiion && !isProtcolLong) {
            _createPosition(
                SharedStructs.PositionType.LONG,
                price,
                poolBalance / expontent,
                address(this)
            );
        } else if (protcolHasToCreatePostiion && isProtcolLong) {
            require(false, "not implemented");
        }

        return true;
    }

    function getShorts() public view returns (SharedStructs.Positon[] memory) {
        return shortPositons;
    }

    function getLongs() public view returns (SharedStructs.Positon[] memory) {
        return longPositions;
    }
}
