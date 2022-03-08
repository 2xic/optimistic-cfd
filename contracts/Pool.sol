//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {EthLongCfd} from "./EthLongCfd.sol";
import {EthShortCfd} from "./EthShortCfd.sol";
import {Chip} from "./Chip.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool {
    Positon[] public longPositions;
    Positon[] public shortPositons;

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
        } else if (position == PositionType.SHORT) {
            require(
                chipToken.transferFrom(msg.sender, address(this), deposited)
            );
            _createPosition(PositionType.SHORT, price, deposited, msg.sender);
            _createPosition(PositionType.LONG, price, deposited, address(this));
        }
        return true;
    }

    function update() public payable returns (bool) {
        /**
            1. rebalance
            2. mint tokens depending on the protcol position
         */
    }

    function rebalancePools() public payable returns (bool) {
        /*
            The update function will should just rebalance the $c between the pools,
            and keep the pools at balance.        
         */
        uint256 price = priceOracle.getLatestPrice();
        uint256 padding = 100 * 100;
        bool isPriceIncrease = lastPrice < price;
        
        if (isPriceIncrease) {
            uint256 delta = ((price * 100 - lastPrice * 100) / lastPrice) * 100;
            for (uint256 i = 0; i < shortPositons.length; i++) {
                console.log(delta);
                shortPositons[i].chipQuantity *= delta;
                shortPositons[i].chipQuantity /= padding;
            }

            for (uint256 i = 0; i < longPositions.length; i++) {
                longPositions[i].chipQuantity *= delta + padding;
                longPositions[i].chipQuantity /= padding;
            }
        }

        lastPrice = price;
    }

    function _createPosition(
        PositionType position,
        uint256 price,
        uint256 deposited,
        address owner
    ) private returns (uint256) {
        require(
            deposited >= price,
            "Deposited deposited has to be greater than the price"
        );
        uint256 mintedTokens = deposited / price;

        if (position == PositionType.LONG) {
            longCfd.exchange(mintedTokens, owner);
            longPositions.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: deposited * expontent,
                    owner: owner
                })
            );
        } else if (position == PositionType.SHORT) {
            shortCfd.exchange(mintedTokens, owner);
            shortPositons.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: deposited * expontent,
                    owner: owner
                })
            );
        }
        return 0;
    }
}

struct Positon {
    uint256 entryPrice;
    uint256 chipQuantity;
    address owner;
}

enum PositionType {
    LONG,
    SHORT
}
