//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

library MathHelper {
	uint256 private constant EXPONENT = 1_000;
	uint256 private constant PERCENTAGE_SCALE = 100;

	function relativeDivide(
		uint256 a,
		uint256 b,
		uint256 c
	) external pure returns (uint256) {
		return
			(a *
				EXPONENT *
				PERCENTAGE_SCALE -
				b *
				EXPONENT *
				PERCENTAGE_SCALE) / (c * EXPONENT);
	}

	// TODO: Figure out how many decimals we actually should store
	// 		 If we want to support many assets, we should probably track 8 decimals	to be on the safe side.
	function safeDivide(uint256 a, uint256 b) external pure returns (uint256) {
		require(b > 0, 'Cannot divide by zero');

		uint256 c = (a * EXPONENT) / (b * EXPONENT);

		return c;
	}

	function multiplyPercentage(uint256 number, uint256 scaledPercentage)
		external
		pure
		returns (uint256)
	{
		return
			(number * (PERCENTAGE_SCALE + scaledPercentage)) / PERCENTAGE_SCALE;
	}

	function max(uint256 a, uint256 b) external pure returns (uint256) {
		return a < b ? b : a;
	}

	function increasePrecision(uint256 number) external pure returns (uint256) {
		return number * EXPONENT;
	}

	function normalizeNumber(uint256 number) external pure returns (uint256) {
		return number / EXPONENT;
	}

	function downAdjustNumber(uint256 currentValue, uint256 downAdjustment) external pure returns (uint256){
		if (currentValue < downAdjustment) {
			return 0;
		}
		return currentValue - downAdjustment;
	}
}
