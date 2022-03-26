//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from '../structs/SharedStructs.sol';
import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';
import {MathHelper} from './MathHelper.sol';

library SimpleRebalanceHelper {
	using MathHelper for uint256;

	function rebalancePools(
		uint256 price,
		SharedStructs.PoolState storage poolState
	) public returns (SharedStructs.PoolState memory) {
		// TODO: I think we need to consider the pool position here berfore moving, write up a test to coverage that case.
		if (poolState.price < price) {
			uint256 relativePriceChange = MathHelper.relativeDivide(
				price,
				poolState.price,
				poolState.price
			);
			uint256 poolAdjustment = MathHelper.multiplyPercentage(
				poolState.longPoolSize,
				relativePriceChange
			) - poolState.longPoolSize;

			poolState.longPoolSize += poolAdjustment;
			poolState.shortPoolSize -= poolAdjustment;
		} else {
			uint256 relativePriceChange = MathHelper.relativeDivide(
				poolState.price,
				price,
				poolState.price
			);

			uint256 poolAdjustment = MathHelper.multiplyPercentage(
				poolState.shortPoolSize,
				relativePriceChange
			) - poolState.shortPoolSize;

			poolState.shortPoolSize += poolAdjustment;
			poolState.longPoolSize -= poolAdjustment;
		}

		return poolState;
	}

	function rebalanceProtcol(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		bool shouldProtcolCashOut = _shouldProtcolCashOut(price, poolState);
		bool isProtcolLong = poolState.protocolState.position ==
			SharedStructs.PositionType.LONG;

		if (shouldProtcolCashOut) {
			if (isProtcolLong) {
				poolState.longPoolSize -= poolState.protocolState.size;
			} else {
				poolState.shortPoolSize -= poolState.protocolState.size;
			}
		}

		poolState = _balance(poolState);

		return poolState;
	}

	function _shouldProtcolCashOut(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) private pure returns (bool) {
		bool isProtcolLong = (poolState.protocolState.position ==
			SharedStructs.PositionType.LONG);
		bool isProtcolShort = (poolState.protocolState.position ==
			SharedStructs.PositionType.SHORT);

		bool longAndPriceIncrease = (poolState.price < price) && isProtcolLong;

		bool shortAndPriceDecrease = (price < poolState.price) &&
			isProtcolShort;

		return longAndPriceIncrease || shortAndPriceDecrease;
	}

	function _balance(SharedStructs.PoolState memory poolState)
		private
		pure
		returns (SharedStructs.PoolState memory)
	{
		bool isProtcolLong = poolState.protocolState.position ==
			SharedStructs.PositionType.LONG;
		bool isOutOfBalance = poolState.longPoolSize != poolState.shortPoolSize;

		if (isOutOfBalance && isProtcolLong) {
			poolState.longPoolSize += (poolState.shortPoolSize -
				poolState.longPoolSize);
		} else if (isOutOfBalance && !isProtcolLong) {
			poolState.shortPoolSize += (poolState.longPoolSize -
				poolState.shortPoolSize);
		}

		return poolState;
	}
}
