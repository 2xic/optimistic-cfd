//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {SharedStructs} from '../../structs/SharedStructs.sol';
import 'hardhat/console.sol';
import {PositionHelper} from './PositionHelper.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/* 
    Deprecated, 
    SimpleRebalanceHelper.sol will replace this file.
*/
library RebalancePoolHelper {
	using PositionHelper for SharedStructs.Position[];

	function rebalancePools(
		uint256 price,
		uint256 lastPrice,
		SharedStructs.PositionType protocolPosition,
		SharedStructs.Position[] storage longPositions,
		SharedStructs.Position[] storage shortPositions
	) public returns (SharedStructs.Rebalance memory) {
		bool isPriceIncrease = lastPrice < price;
		bool isPriceDecrease = lastPrice > price;

		uint256 minted = 0;

		if (isPriceIncrease) {
			uint256 delta = ((price * 100 - lastPrice * 100) / lastPrice) * 100;

			minted = _positionChipAdjustments(
				protocolPosition,
				longPositions,
				shortPositions,
				delta,
				SharedStructs.PriceMovement.UP
			);
		} else if (isPriceDecrease) {
			uint256 delta = ((lastPrice * 100 - price * 100) / lastPrice) * 100;

			minted = _positionChipAdjustments(
				protocolPosition,
				longPositions,
				shortPositions,
				delta,
				SharedStructs.PriceMovement.DOWN
			);
		}

		bool isPriceMovement = isPriceIncrease || isPriceDecrease;

		return
			PositionHelper.getRebalance(
				isPriceMovement,
				isPriceIncrease,
				minted,
				price
			);
	}

	function rebalanceProtocolExposure(
		SharedStructs.Position memory position,
		uint256 amount,
		uint256 price,
		uint256 adjustment,
		IERC20 chipToken,
		address treasuryAddress,
		bool isProtocolLong
	) public returns (SharedStructs.Position memory) {
		if (price == position.entryPrice) {
			position.chipQuantity -= adjustment;
		} else if (amount <= position.entryChipQuantity) {
			bool hasShortProfits = !isProtocolLong &&
				price < position.entryPrice;

			if (hasShortProfits) {
				uint256 profits = PositionHelper.calculateProfits(
					position,
					amount,
					price
				);
				chipToken.approve(address(this), profits);
				chipToken.transferFrom(address(this), treasuryAddress, profits);

				uint256 newBalance = PositionHelper
					.getProtocolChipAdjustmentBalance(position, adjustment);
				position.chipQuantity = newBalance;
				position.entryChipQuantity = newBalance;
			} else {
				require(false, 'Not implemented');
			}
		}

		return position;
	}

	function _positionChipAdjustments(
		SharedStructs.PositionType protocolPosition,
		SharedStructs.Position[] storage longPositions,
		SharedStructs.Position[] storage shortPositions,
		uint256 priceChange,
		SharedStructs.PriceMovement direction
	) public returns (uint256) {
		PositionHelper.moveChipBetweenPositions(
			priceChange,
			protocolPosition,
			direction,
			longPositions,
			shortPositions
		);
		uint256 poolBalance = PositionHelper.getPoolBalance(
			direction,
			longPositions,
			shortPositions
		);
		return poolBalance;
	}
}
