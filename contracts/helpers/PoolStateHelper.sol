//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import {MathHelper} from './MathHelper.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';

library PoolStateHelper {
	function isProtcolLong(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (bool)
	{
		return
			poolState.protocolState.position == SharedStructs.PositionType.LONG;
	}

	function isProtcolShort(SharedStructs.PoolState memory poolState)
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

	function isProtcolPartipatcing(SharedStructs.PoolState memory poolState)
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

	function getProtcolReedemPrice(SharedStructs.PoolState memory poolState)
		public
		pure
		returns (uint256)
	{
		return
			poolState.protocolState.position == SharedStructs.PositionType.LONG
				? poolState.shortRedeemPrice
				: poolState.longRedeemPrice;
	}
}
