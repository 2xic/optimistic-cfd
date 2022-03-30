//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from '../structs/SharedStructs.sol';
import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';
import {MathHelper} from './MathHelper.sol';
import {ExchangeHelper} from './ExchangeHelper.sol';
import {PoolStateHelper} from './PoolStateHelper.sol';

library SimpleRebalanceHelper {
	using MathHelper for uint256;
	using PoolStateHelper for SharedStructs.PoolState;

	function rebalancePools(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
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
			uint256 reedemPrice = poolState.getProtcolReedemPrice();
			uint256 cfdAdjustment = ExchangeHelper.getMinted(
				reedemPrice,
				poolAdjustment.normalizeNumber()
			);

			poolState.protocolState.size -= poolAdjustment;
			poolState.protocolState.cfdSize -= cfdAdjustment;
			if (
				poolState.protocolState.position ==
				SharedStructs.PositionType.LONG
			) {
				poolState.longPoolSize -= poolAdjustment;
				poolState.longSupply -= cfdAdjustment;
			} else {
				poolState.shortPoolSize -= poolAdjustment;
				poolState.shortSupply -= cfdAdjustment;
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
				poolState.longSupply -= poolState.protocolState.cfdSize;
				poolState.protocolState.size = 0;
				poolState.protocolState.cfdSize = 0;
			} else {
				poolState.protocolState.size -= poolAdjustment;
				require(false, 'not implemented cfd adjustment');
			}
		} else if (
			!isPriceIncrease &&
			poolState.protocolState.position == SharedStructs.PositionType.SHORT
		) {
			bool hasAdjustmentLiquidatedThePool = MathHelper.max(
				poolState.protocolState.size,
				poolAdjustment
			) == poolAdjustment;

			if (hasAdjustmentLiquidatedThePool) {
				poolState.shortSupply -= poolState.protocolState.cfdSize;
				poolState.protocolState.size = 0;
				poolState.protocolState.cfdSize = 0;
			} else {
				poolState.protocolState.size -= poolAdjustment;
				require(false, 'not implemented cfd adjustment');
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
				poolState.longSupply -= poolState.protocolState.cfdSize;
			} else {
				poolState.shortPoolSize -= poolState.protocolState.size;
				poolState.shortSupply -= poolState.protocolState.cfdSize;
			}
		}

		poolState = _balance(poolState, price);

		return poolState;
	}

	function _shouldProtcolCashOut(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) private pure returns (bool) {
		bool isProtcolLong = poolState.isProtcolLong();
		bool isProtcolShort = poolState.isProtcolShort();

		bool longAndPriceIncrease = (poolState.price <= price) && isProtcolLong;

		bool shortAndPriceDecrease = (price <= poolState.price) &&
			isProtcolShort;

		return longAndPriceIncrease || shortAndPriceDecrease;
	}

	function _balance(SharedStructs.PoolState memory poolState, uint256 price)
		private
		pure
		returns (SharedStructs.PoolState memory)
	{
		bool isProtcolLong = poolState.isProtcolLong();
		bool isOutOfBalance = poolState.isUnbalanced();
		bool isProtcolActive = poolState.isProtcolPartipatcing();

		// TODO : this is wrong
		if (isProtcolActive) {
			if (isOutOfBalance && isProtcolLong) {
				poolState.longPoolSize += (poolState.shortPoolSize -
					poolState.longPoolSize);
			} else if (isOutOfBalance && !isProtcolLong) {
				poolState.shortPoolSize += (poolState.longPoolSize -
					poolState.shortPoolSize);
			}
		}

		poolState = _revalule(poolState, price);

		if (poolState.longPoolSize < poolState.shortPoolSize) {
			poolState = _mint(poolState, SharedStructs.PositionType.LONG);
		} else if (poolState.shortPoolSize < poolState.longPoolSize) {
			poolState = _mint(poolState, SharedStructs.PositionType.SHORT);
		}

		return poolState;
	}

	function _mint(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType pool
	) private pure returns (SharedStructs.PoolState memory) {
		bool isAlgined = poolState.protocolState.size == 0 ||
			poolState.protocolState.position == pool;
		require(isAlgined, 'Only aligned position supportted currently');

		// chip token needed to be mintted = diff
		// migth have to move this to the main pool contrract to simplify this
		if (pool == SharedStructs.PositionType.LONG) {
			uint256 delta = (poolState.shortPoolSize - poolState.longPoolSize);
			poolState = poolState.setPoolPosition(
				SharedStructs.PositionType.LONG,
				delta
			);
			uint256 deltaCfd = ExchangeHelper.getMinted(
				poolState.longRedeemPrice,
				delta.normalizeNumber()
			);
			poolState.longSupply += deltaCfd;
			poolState.protocolState.cfdSize += deltaCfd;
		} else {
			uint256 delta = (poolState.longPoolSize - poolState.shortPoolSize);
			poolState = poolState.setPoolPosition(
				SharedStructs.PositionType.SHORT,
				delta
			);
			uint256 deltaCfd = ExchangeHelper.getMinted(
				poolState.shortRedeemPrice,
				delta.normalizeNumber()
			);
			poolState.shortSupply += deltaCfd;
			poolState.protocolState.cfdSize += deltaCfd;
		}

		return poolState;
	}

	function _revalule(SharedStructs.PoolState memory poolState, uint256 price)
		private
		pure
		returns (SharedStructs.PoolState memory)
	{
		poolState.shortRedeemPrice = MathHelper.safeDivide(
			poolState.shortPoolSize.normalizeNumber(),
			poolState.shortSupply
		);
		poolState.longRedeemPrice = price;

		return poolState;
	}
}
