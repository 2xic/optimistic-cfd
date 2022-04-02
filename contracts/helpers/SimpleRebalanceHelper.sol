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
		// TODO: I think we need to consider the pool position here before moving, write up a test to coverage that case.

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

			poolState = _reduceProtocolPosition(
				poolAdjustment,
				true,
				poolState
			);
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

			poolState = _reduceProtocolPosition(
				poolAdjustment,
				false,
				poolState
			);
		}

		return poolState;
	}

	function repositionPool(
		SharedStructs.PositionType position,
		uint256 poolAdjustment,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		if (poolState.protocolState.position == position) {
			uint256 redeemPrice = poolState.getProtocolRedeemPrice();
			uint256 cfdAdjustment = ExchangeHelper.getMinted(
				redeemPrice,
				poolAdjustment.normalizeNumber()
			);

			poolState = poolState.downgradeProtocolPosition(
				cfdAdjustment,
				poolAdjustment
			);
		}

		return poolState;
	}

	function _reduceProtocolPosition(
		uint256 poolAdjustment,
		bool isPriceIncrease,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		if (isPriceIncrease && poolState.isProtocolLong()) {
			bool hasAdjustmentLiquidatedThePool = MathHelper.max(
				poolState.protocolState.size,
				poolAdjustment
			) == poolAdjustment;

			if (hasAdjustmentLiquidatedThePool) {
				poolState = poolState.cashOutProtocol();
			} else {
				poolState.protocolState.size -= poolAdjustment;
				require(false, 'not implemented cfd adjustment');
			}
		} else if (!isPriceIncrease && poolState.isProtocolShort()) {
			bool hasAdjustmentLiquidatedThePool = MathHelper.max(
				poolState.protocolState.size,
				poolAdjustment
			) == poolAdjustment;

			if (hasAdjustmentLiquidatedThePool) {
				poolState = poolState.cashOutProtocol();
			} else {
				poolState.protocolState.size -= poolAdjustment;
				require(false, 'not implemented cfd adjustment');
			}
		}

		return poolState;
	}

	function rebalanceProtocol(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) public pure returns (SharedStructs.PoolState memory) {
		bool shouldProtocolCashOut = _shouldProtocolCashOut(price, poolState);
		bool canCashOut = poolState.isProtocolParticipating();
		bool isProtocolLong = poolState.isProtocolLong();

		if (shouldProtocolCashOut && canCashOut) {
			if (isProtocolLong) {
				poolState.cashOutProtocol();
			} else {
				poolState.cashOutProtocol();
			}
		}

		poolState = _balance(poolState, price);

		return poolState;
	}

	function _shouldProtocolCashOut(
		uint256 price,
		SharedStructs.PoolState memory poolState
	) private pure returns (bool) {
		bool isProtocolLong = poolState.isProtocolLong();
		bool isProtocolShort = poolState.isProtocolShort();

		bool longAndPriceIncrease = (poolState.price <= price) &&
			isProtocolLong;

		bool shortAndPriceDecrease = (price <= poolState.price) &&
			isProtocolShort;

		return longAndPriceIncrease || shortAndPriceDecrease;
	}

	function _balance(SharedStructs.PoolState memory poolState, uint256 price)
		private
		pure
		returns (SharedStructs.PoolState memory)
	{
		bool isProtocolLong = poolState.isProtocolLong();
		bool isOutOfBalance = poolState.isUnbalanced();
		bool isProtocolActive = poolState.isProtocolParticipating();

		// TODO : this is wrong
		if (isProtocolActive) {
			if (isOutOfBalance && isProtocolLong) {
				poolState.longPoolSize += (poolState.shortPoolSize -
					poolState.longPoolSize);
			} else if (isOutOfBalance && !isProtocolLong) {
				poolState.shortPoolSize += (poolState.longPoolSize -
					poolState.shortPoolSize);
			}
		}

		poolState = _revalue(poolState, price);

		bool isShortPoolBigger = poolState.longPoolSize <
			poolState.shortPoolSize;
		bool isLongPoolBigger = poolState.shortPoolSize <
			poolState.longPoolSize;

		if (isShortPoolBigger) {
			poolState = _mint(poolState, SharedStructs.PositionType.LONG);
		} else if (isLongPoolBigger) {
			poolState = _mint(poolState, SharedStructs.PositionType.SHORT);
		}

		return poolState;
	}

	function _mint(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType pool
	) private pure returns (SharedStructs.PoolState memory) {
		bool isAligned = poolState.protocolState.size == 0 ||
			poolState.protocolState.position == pool;
		require(isAligned, 'Only aligned position supported currently');

		// chip token needed to be minted = diff
		// might have to move this to the main pool contract to simplify this

		uint256 delta = pool == SharedStructs.PositionType.LONG
			? (poolState.shortPoolSize - poolState.longPoolSize)
			: (poolState.longPoolSize - poolState.shortPoolSize);

		poolState = poolState.setPoolPosition(pool, delta);

		uint256 deltaCfd = ExchangeHelper.getMinted(
			poolState.getRedeemPrice(pool),
			delta.normalizeNumber()
		);

		if (pool == SharedStructs.PositionType.LONG) {
			poolState.longSupply += deltaCfd;
			poolState.protocolState.cfdSize += deltaCfd;
		} else if (pool == SharedStructs.PositionType.SHORT) {
			poolState.shortSupply += deltaCfd;
			poolState.protocolState.cfdSize += deltaCfd;
		} else {
			require(false, 'Unknown state');
		}

		return poolState;
	}

	function _revalue(SharedStructs.PoolState memory poolState, uint256 price)
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
