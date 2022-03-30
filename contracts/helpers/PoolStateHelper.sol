//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import {MathHelper} from './MathHelper.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';

library PoolStateHelper {
	function isProtocolLong(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return
			poolState.protocolState.position == SharedStructs.PositionType.LONG;
	}

	function isProtocolShort(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return
			poolState.protocolState.position ==
			SharedStructs.PositionType.SHORT;
	}

	function isUnbalanced(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return poolState.longPoolSize != poolState.shortPoolSize;
	}

	function isProtocolParticipating(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return poolState.protocolState.size > 0;
	}

	function setPoolPosition(
		SharedStructs.PoolState memory poolState,
		SharedStructs.PositionType pool,
		uint256 size
	) public pure returns (SharedStructs.PoolState memory) {
		poolState.protocolState.position = pool;
		if (pool == SharedStructs.PositionType.LONG) {
			poolState.protocolState.size = size;
			poolState.longPoolSize += size;
		} else {
			poolState.protocolState.size = size;
			poolState.longPoolSize += size;
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

	function cashOutProtocol(SharedStructs.PoolState memory poolState)
		public
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

	function downgradeProtocolPosition(
		SharedStructs.PoolState memory poolState,
		uint256 cfdAdjustment,
		uint256 chipAdjustment
	) public pure returns (SharedStructs.PoolState memory) {
		if (isProtocolLong(poolState)) {
			poolState.longSupply -= cfdAdjustment;
			poolState.longPoolSize -= chipAdjustment;
		} else {
			poolState.shortSupply -= cfdAdjustment;
			poolState.shortPoolSize -= chipAdjustment;
		}
		poolState.protocolState.size -= chipAdjustment;
		poolState.protocolState.cfdSize -= cfdAdjustment;

		return poolState;
	}
}