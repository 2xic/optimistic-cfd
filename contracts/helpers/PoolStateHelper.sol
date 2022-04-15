//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import {MathHelper} from './MathHelper.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';

library PoolStateHelper {
	using MathHelper for uint256;

	function isProtocolLong(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return
			poolState.protocolState.position == SharedStructs.PositionType.LONG;
	}

	function isProtocolShort(SharedStructs.PoolState memory poolState)
		external
		pure
		returns (bool)
	{
		return
			poolState.protocolState.position ==
			SharedStructs.PositionType.SHORT;
	}

	function isUnbalanced(SharedStructs.PoolState memory poolState)
		external
		pure
		returns (bool)
	{
		return poolState.longPoolSize != poolState.shortPoolSize;
	}

	function isProtocolParticipating(SharedStructs.PoolState memory poolState)
		external
		pure
		returns (bool)
	{
		return poolState.protocolState.size > 0;
	}

	function setPoolPosition(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType pool,
		uint256 size
	) external pure returns (SharedStructs.PoolState memory) {
		poolState.protocolState.position = pool;

		if (pool == SharedStructs.PositionType.LONG) {
			poolState.protocolState.size = size;
			poolState.longPoolSize += size;
		} else if (pool == SharedStructs.PositionType.SHORT) {
			poolState.protocolState.size = size;
			poolState.shortPoolSize += size;
		} else {
			require(false, 'Unknown state');
		}

		return poolState;
	}

	function getProtocolRedeemPrice(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (uint256)
	{
		return getRedeemPrice(poolState, poolState.protocolState.position);
	}

	function getRedeemPrice(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType pool
	) public pure returns (uint256) {
		return
			pool == SharedStructs.PositionType.LONG
				? poolState.longRedeemPrice
				: poolState.shortRedeemPrice;
	}

	function downgradeProtocolPosition(
		SharedStructs.PoolState memory poolState,
		uint256 cfdAdjustment,
		uint256 chipAdjustment
	) internal pure returns (SharedStructs.PoolState memory) {
		if (isProtocolLong(poolState)) {
			poolState.longSupply = poolState.longSupply.downAdjustNumber(
				cfdAdjustment
			);
			poolState.longPoolSize = poolState.longPoolSize.downAdjustNumber(
				chipAdjustment
			);
		} else {
			poolState.shortSupply = poolState.shortSupply.downAdjustNumber(
				cfdAdjustment
			);
			poolState.shortPoolSize = poolState.shortPoolSize.downAdjustNumber(
				chipAdjustment
			);
		}

		poolState.protocolState.size = poolState
			.protocolState
			.size
			.downAdjustNumber(chipAdjustment);
		poolState.protocolState.cfdSize = poolState
			.protocolState
			.cfdSize
			.downAdjustNumber(cfdAdjustment);

		return poolState;
	}

	function cashOutProtocol(SharedStructs.PoolState memory poolState)
		external
		pure
		returns (SharedStructs.PoolState memory)
	{
		poolState = downgradeProtocolPosition(
			poolState,
			poolState.protocolState.cfdSize,
			poolState.protocolState.size
		);
		return poolState;
	}

	function canProtocolEnterPosition(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType position
	) external pure returns (bool) {
		if (poolState.protocolState.position == position) {
			return true;
		} else if (poolState.protocolState.size == 0) {
			return true;
		} else {
			return false;
		}
	}
}
