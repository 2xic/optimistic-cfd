//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import { MathHelper } from './MathHelper.sol';

library ExchangeHelper {
	using MathHelper for uint256;

    // TODO: I think this can be solved better if you just rescale the numbers
    function getExchangedAmount(
        uint256 price,
        uint256 deposited
    ) public pure returns (uint256) {
        uint256 leftover = deposited % price;
		uint256 rawDeposited = deposited - leftover;
        return rawDeposited;
    }

    function getMinted(
        uint256 price,
        uint256 deposited
    ) public pure returns (uint256) {
		uint256 rawDeposited = getExchangedAmount(price, deposited);
        return MathHelper.safeDivide(rawDeposited, price);
    }
}