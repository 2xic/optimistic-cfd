//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {EthLongCfd} from "./EthLongCfd.sol";
import {EthShortCfd} from "./EthShortCfd.sol";
import {Chip} from "./Chip.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SharedStructs} from "./structs/SharedStructs.sol";
import {PositionHelper} from "./PositionHelper.sol";

contract Pool {
    using PositionHelper for SharedStructs.Positon[];

    SharedStructs.Positon[] public longPositions;
    SharedStructs.Positon[] public shortPositons;
    SharedStructs.PositionType public protcolPosition;

    IPriceOracle private priceOracle;
    IERC20 private chipToken;
    EthLongCfd private longCfd;
    EthShortCfd private shortCfd;

    uint256 private lastPrice;
    uint16 private expontent;

    constructor(
        address _priceFeed,
        address _chipToken,
        address _longTCfd,
        address _shortCfd
    ) {
        priceOracle = IPriceOracle(_priceFeed);
        longCfd = EthLongCfd(_longTCfd);
        shortCfd = EthShortCfd(_shortCfd);
        chipToken = IERC20(_chipToken);
        expontent = 1000;
    }

    function init(uint256 amount, SharedStructs.PositionType position)
        public
        payable
        returns (bool)
    {
        require(lastPrice == 0, "Init should only be called once");

        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);
        lastPrice = price;

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
        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);

        bool isOverwritingProtcol = position == protcolPosition;

        if (isOverwritingProtcol) {
            _createPosition(position, price, deposited, msg.sender);
            _redjuceProtcolPosition(deposited, price);
        }
        return true;
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
                    entryPrice: rebalance.price,
                    chipQuantity: rebalance.minted,
                    owner: address(this)
                })
            );
        } else if (priceMovedAgainstProtcoShort) {
            shortPositons.push(
                SharedStructs.Positon({
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
        bool isPriceIncrease = lastPrice < price;
        bool isPriceDecrease = lastPrice > price;

        uint256 minted = 0;

        if (isPriceIncrease) {
            uint256 delta = ((price * 100 - lastPrice * 100) / lastPrice) * 100;

            minted = _positionChipAdjustments(
                delta,
                SharedStructs.PriceMovment.UP
            );
        } else if (isPriceDecrease) {
            uint256 delta = ((lastPrice * 100 - price * 100) / lastPrice) * 100;

            minted = _positionChipAdjustments(
                delta,
                SharedStructs.PriceMovment.DOWN
            );
        }

        lastPrice = price;

        bool isPriceMovment = isPriceIncrease || isPriceDecrease;

        if (isPriceMovment) {
            return
                SharedStructs.Rebalance({
                    direction: isPriceIncrease
                        ? SharedStructs.PriceMovment.UP
                        : SharedStructs.PriceMovment.DOWN,
                    minted: minted,
                    price: price
                });
        }

        return
            SharedStructs.Rebalance({
                direction: SharedStructs.PriceMovment.STABLE,
                minted: minted,
                price: price
            });
    }

    function _positionChipAdjustments(
        uint256 delta,
        SharedStructs.PriceMovment direction
    ) private returns (uint256) {
        uint256 padding = 100 * 100;
        bool isProtcolWinning = protcolPosition ==
            SharedStructs.PositionType.SHORT &&
            direction == SharedStructs.PriceMovment.DOWN;

        for (uint256 i = 0; i < shortPositons.length; i++) {
            if (!isProtcolWinning) {
                shortPositons[i].chipQuantity *= (
                    direction == SharedStructs.PriceMovment.DOWN
                        ? delta + padding
                        : delta
                );
                shortPositons[i].chipQuantity /= padding;
            } else if (shortPositons[i].owner == address(this)) {
                shortPositons[i].chipQuantity *= delta;
                shortPositons[i].chipQuantity /= padding;
            }
        }

        for (uint256 i = 0; i < longPositions.length; i++) {
            longPositions[i].chipQuantity *= (
                direction == SharedStructs.PriceMovment.UP
                    ? delta + padding
                    : delta
            );
            longPositions[i].chipQuantity /= padding;
        }

        uint256 poolBalance = 0;
        SharedStructs.Positon[] storage bigPool = (
            direction == SharedStructs.PriceMovment.DOWN
                ? shortPositons
                : longPositions
        );
        SharedStructs.Positon[] storage smallPool = (
            direction == SharedStructs.PriceMovment.DOWN
                ? longPositions
                : shortPositons
        );
        for (uint256 i = 0; i < bigPool.length; i++) {
            poolBalance += bigPool[i].chipQuantity;
        }
        for (uint256 i = 0; i < smallPool.length; i++) {
            poolBalance -= smallPool[i].chipQuantity;
        }

        return poolBalance;
    }

    function _createPosition(
        SharedStructs.PositionType position,
        uint256 price,
        uint256 deposited,
        address owner
    ) private returns (uint256) {
        uint256 mintedTokens = deposited / price;

        if (position == SharedStructs.PositionType.LONG) {
            longCfd.exchange(mintedTokens, owner);
            longPositions.push(
                SharedStructs.Positon({
                    entryPrice: price,
                    chipQuantity: deposited * expontent,
                    owner: owner
                })
            );
        } else if (position == SharedStructs.PositionType.SHORT) {
            shortCfd.exchange(mintedTokens, owner);
            shortPositons.push(
                SharedStructs.Positon({
                    entryPrice: price,
                    chipQuantity: deposited * expontent,
                    owner: owner
                })
            );
        }
        return 0;
    }

    function _redjuceProtcolPosition(uint256 amount, uint256 price)
        private
        returns (bool)
    {
        SharedStructs.Positon[] storage positions = (
            protcolPosition == SharedStructs.PositionType.LONG
                ? longPositions
                : shortPositons
        );

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].owner == address(this)) {
                if (price == positions[i].entryPrice) {
                    positions[i].chipQuantity -= amount * expontent;
                    positions.remove(i);
                }
            }
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
