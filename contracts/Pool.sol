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
        console.log(position == PositionType.LONG);

        if (position == PositionType.LONG) {
            require(chipToken.transferFrom(msg.sender, address(this), amount));
            longCfd.exchange(amount, msg.sender);
            longPositions.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: amount,
                    owner: msg.sender
                })
            );
            shortCfd.exchange(amount, address(this));
            shortPositons.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: amount,
                    owner: address(this)
                })
            );
        } else if (position == PositionType.SHORT) {
            require(chipToken.transferFrom(msg.sender, address(this), amount));
            shortCfd.exchange(amount, msg.sender);
            shortPositons.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: amount,
                    owner: msg.sender
                })
            );
            longCfd.exchange(amount, address(this));
            longPositions.push(
                Positon({
                    entryPrice: price,
                    chipQuantity: amount,
                    owner: address(this)
                })
            );
        }
        return true;
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
