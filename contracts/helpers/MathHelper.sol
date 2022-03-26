//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

library MathHelper {
	uint256 private constant EXPONENT = 1000;
	uint256 private constant PERCENTAGE_SCALE = 100;

	function relativeDivide(
		uint256 a,
		uint256 b,
		uint256 c
	) public pure returns (uint256) {
		return
			(a *
				EXPONENT *
				PERCENTAGE_SCALE -
				b *
				EXPONENT *
				PERCENTAGE_SCALE) / (c * EXPONENT);
	}

	function multiplyPercentage(uint256 number, uint256 scaledPercentage)
		public
		pure
		returns (uint256)
	{
		return
			(number * (PERCENTAGE_SCALE + scaledPercentage)) / PERCENTAGE_SCALE;
	}

	function increasePrecision(uint256 number) public pure returns (uint256) {
		return number * EXPONENT;
	}

	function normalizeNumber(uint256 number) public pure returns (uint256) {
		return number / EXPONENT;
	}
}
