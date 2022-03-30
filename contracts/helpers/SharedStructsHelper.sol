//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import {MathHelper} from './MathHelper.sol';
import {SharedStructs} from '../structs/SharedStructs.sol';

library SharedStructsHelper {
	function getOppositePositon(SharedStructs.PositionType position)
		public
		pure
		returns (SharedStructs.PositionType)
	{
		if (position == SharedStructs.PositionType.LONG) {
			return SharedStructs.PositionType.SHORT;
		} else {
			return SharedStructs.PositionType.LONG;
		}
	}
}
