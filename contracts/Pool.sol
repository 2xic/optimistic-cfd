//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {EthLongCfd} from "./EthLongCfd.sol";
import {EthShortCfd} from "./EthShortCfd.sol";
import {Chip} from "./Chip.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SharedStructs} from "./structs/Postion.sol";
import {PositionHelper} from "./PositionHelper.sol";

contract Pool {
    SharedStructs.Positon[] public longPositions;
    SharedStructs.Positon[] public shortPositons;
    PositionType protcolPosition;

    IPriceOracle priceOracle;
    IERC20 public chipToken;
    EthLongCfd longCfd;
    EthShortCfd shortCfd;

    uint256 lastPrice;
    uint16 expontent;

    constructor(
        address priceFeed,
        address _chipToken,
        address _longTCfd,
        address _shortCfd
    ) {
        priceOracle = IPriceOracle(priceFeed);
        longCfd = EthLongCfd(_longTCfd);
        shortCfd = EthShortCfd(_shortCfd);
        chipToken = IERC20(_chipToken);
        expontent = 1000;
    }

    function init(uint256 amount, PositionType position)
        public
        payable
        returns (bool)
    {
        /*
            Because the pools are empty, the inital price of the 
            synethic tokens has to be priced as the value of the 
            underlying asset. 
            The protcol will take the other side of the trade.
         */

        require(lastPrice == 0, "Init should only be called once");

        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);
        lastPrice = price;

        if (position == PositionType.LONG) {
            require(
                chipToken.transferFrom(msg.sender, address(this), deposited)
            );
            _createPosition(PositionType.LONG, price, deposited, msg.sender);
            _createPosition(
                PositionType.SHORT,
                price,
                deposited,
                address(this)
            );
            protcolPosition = PositionType.SHORT;
        } else if (position == PositionType.SHORT) {
            require(
                chipToken.transferFrom(msg.sender, address(this), deposited)
            );
            _createPosition(PositionType.SHORT, price, deposited, msg.sender);
            _createPosition(PositionType.LONG, price, deposited, address(this));
            protcolPosition = PositionType.LONG;
        }
        return true;
    }

    function enter(uint256 amount, PositionType position)
        public
        payable
        returns (bool)
    {
        /*
            1,. 
         */
        uint256 price = priceOracle.getLatestPrice();
        uint256 leftover = amount % price;
        uint256 deposited = (amount - leftover);

        bool isOverwritingProtcol = position == protcolPosition;

        if (isOverwritingProtcol) {
            _createPosition(position, price, deposited, msg.sender);
            _redjuceProtcolPosition(deposited, price);
        } else {
            /*
                Protcol needs to mint more on it's side of the trade.
            */
        }

        return true;
    }

    function update() public payable returns (bool) {
        /**
            1. Move the chips between pools
            2. Balance out the pools.
         */
        Rebalance memory rebalance = rebalancePools();
        bool priceMovedAgainstProtcolLong = (protcolPosition ==
            PositionType.LONG &&
            rebalance.direction == PriceMovment.DOWN);
        bool priceMovedAgainstProtcoShort = (protcolPosition ==
            PositionType.SHORT &&
            rebalance.direction == PriceMovment.UP);

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
    }

    function rebalancePools() public payable returns (Rebalance memory) {
        /*
            The update function will should just rebalance the $c between the pools,
            and keep the pools at balance.        
         */
        uint256 price = priceOracle.getLatestPrice();
        bool isPriceIncrease = lastPrice < price;
        bool isPriceDecrease = lastPrice > price;

        uint256 minted = 0;

        if (isPriceIncrease) {
            uint256 delta = ((price * 100 - lastPrice * 100) / lastPrice) * 100;

            minted = _position_chip_adjustments(delta, PriceMovment.UP);
        } else if (isPriceDecrease) {
            uint256 delta = ((lastPrice * 100 - price * 100) / lastPrice) * 100;

            minted = _position_chip_adjustments(delta, PriceMovment.DOWN);
        }

        lastPrice = price;

        if (isPriceIncrease || isPriceDecrease) {
            return
                Rebalance({
                    direction: isPriceIncrease
                        ? PriceMovment.UP
                        : PriceMovment.DOWN,
                    minted: minted,
                    price: price
                });
        }

        return
            Rebalance({
                direction: PriceMovment.STABLE,
                minted: minted,
                price: price
            });
    }

    function _enter_position(uint256 amount) private returns (uint256) {}

    function _position_chip_adjustments(uint256 delta, PriceMovment direction)
        private
        returns (uint256)
    {
        uint256 padding = 100 * 100;
        bool isProtcolWinning = protcolPosition == PositionType.SHORT &&
            direction == PriceMovment.DOWN;

        for (uint256 i = 0; i < shortPositons.length; i++) {
            if (!isProtcolWinning) {
                shortPositons[i].chipQuantity *= (
                    direction == PriceMovment.DOWN ? delta + padding : delta
                );
                shortPositons[i].chipQuantity /= padding;
            } else if (shortPositons[i].owner == address(this)) {
                shortPositons[i].chipQuantity *= delta;
                shortPositons[i].chipQuantity /= padding;
            }
        }

        for (uint256 i = 0; i < longPositions.length; i++) {
            longPositions[i].chipQuantity *= (
                direction == PriceMovment.UP ? delta + padding : delta
            );
            longPositions[i].chipQuantity /= padding;
        }

        uint256 poolBalance = 0;
        SharedStructs.Positon[] storage bigPool = (
            direction == PriceMovment.DOWN ? shortPositons : longPositions
        );
        SharedStructs.Positon[] storage smallPool = (
            direction == PriceMovment.DOWN ? longPositions : shortPositons
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
        PositionType position,
        uint256 price,
        uint256 deposited,
        address owner
    ) private returns (uint256) {
        /*
        require(
            deposited >= price,
            "Deposited deposited has to be greater than the price"
        );
        */
        uint256 mintedTokens = deposited / price;

        if (position == PositionType.LONG) {
            longCfd.exchange(mintedTokens, owner);
            longPositions.push(
                SharedStructs.Positon({
                    entryPrice: price,
                    chipQuantity: deposited * expontent,
                    owner: owner
                })
            );
        } else if (position == PositionType.SHORT) {
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

    /*
    using PositionHelper for PositionHelper.Storage;
    PositionHelper.Storage positionStorage;
    */


    function _redjuceProtcolPosition(uint256 amount, uint256 price)
        private
        returns (bool)
    {
        SharedStructs.Positon[] storage positions = (
            protcolPosition == PositionType.LONG ? longPositions : shortPositons
        );

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].owner == address(this)) {
                // Todo : Should withdrawl to tressury if profits, etc.
                // Todo : if the deposited amount is greater than the exposoure of the protcol then the protcol has to create a position on the other side of the trade.
                positions[i].chipQuantity -= amount * expontent;
    //            positionStorage.remove(i);
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
