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
		SharedStructs.PoolState memory poolState
	) public view returns (SharedStructs.PoolState memory) {
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

			poolState = _reduceProtcolSize(poolAdjustment, true, poolState);
		} else if (price < poolState.price) {
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

			poolState = _reduceProtcolSize(poolAdjustment, false, poolState);
		}

		return poolState;
	}

	function repositionPool(
		SharedStructs.PositionType position,
		uint256 poolAdjustment,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		if (poolState.protocolState.position == position) {
			poolState.protocolState.size -= poolAdjustment;
			if (poolState.protocolState.position == SharedStructs.PositionType.LONG) {
				poolState.longPoolSize -= poolAdjustment;
			} else {
				poolState.shortPoolSize -= poolAdjustment;
			}
		}

		return poolState;
	}

	function _reduceProtcolSize(
		uint256 poolAdjustment,
		bool isPriceIncrease,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		if (
			isPriceIncrease &&
			poolState.protocolState.position == SharedStructs.PositionType.LONG
		) {
			bool hasAdjustmentLiquidatedThePool = MathHelper.max(
				poolState.protocolState.size,
				poolAdjustment
			) == poolAdjustment;

			if (hasAdjustmentLiquidatedThePool) {
				poolState.protocolState.size = 0;
			} else {
				poolState.protocolState.size -= poolAdjustment;
			}
		}

		return poolState;
	}

	function rebalanceProtcol(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		bool shouldProtcolCashOut = _shouldProtcolCashOut(price, poolState);
		bool canCashOut = 0 < poolState.protocolState.size;
		bool isProtcolLong = poolState.protocolState.position ==
			SharedStructs.PositionType.LONG;

		if (shouldProtcolCashOut && canCashOut) {
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
