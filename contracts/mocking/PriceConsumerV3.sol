//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '../interfaces/IPriceOracle.sol';

contract MockPriceOracle is IPriceOracle {
	uint256 price;

	constructor() {
		price = 5;
	}

	function setPrice(uint256 _price) public payable returns (uint256) {
		price = _price;
		return _price;
	}

	function getLatestPrice() public override returns (uint256) {
		return price;
	}
}
