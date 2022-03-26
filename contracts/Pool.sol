//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IPriceOracle} from './interfaces/IPriceOracle.sol';
import {EthLongCfd} from './tokens/EthLongCfd.sol';
import {EthShortCfd} from './tokens/EthShortCfd.sol';
import {Treasury} from './Treasury.sol';
import {Chip} from './tokens/Chip.sol';
import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SharedStructs} from './structs/SharedStructs.sol';
import {PositionHelper} from './helpers/PositionHelper.sol';
import {RebalancePoolHelper} from './helpers/RebalancePoolHelper.sol';
import {SimpleRebalanceHelper} from './helpers/SimpleRebalanceHelper.sol';
import {MathHelper} from './helpers/MathHelper.sol';

contract Pool {
	using PositionHelper for SharedStructs.Position[];
	using RebalancePoolHelper for SharedStructs.Position[];
	using MathHelper for uint256;
	using SimpleRebalanceHelper for SharedStructs.PoolState;

	SharedStructs.Position[] private longPositions;
	SharedStructs.Position[] private shortPositions;
	SharedStructs.PositionType private protocolPosition;
	SharedStructs.PoolState private poolState;

	IPriceOracle private priceOracle;
	IERC20 private chipToken;
	EthLongCfd private longCfd;
	EthShortCfd private shortCfd;
	Treasury private treasury;

	bool private isInitialized;
	uint256 private lastPrice;
	uint16 private exponent;
	uint256 private fee;

	constructor(
		address _priceFeed,
		address _chipToken,
		address _longTCfd,
		address _shortCfd,
		address _treasury,
		uint256 _fee
	) {
		priceOracle = IPriceOracle(_priceFeed);
		longCfd = EthLongCfd(_longTCfd);
		shortCfd = EthShortCfd(_shortCfd);
		chipToken = IERC20(_chipToken);
		treasury = Treasury(_treasury);
		exponent = 1000;
		isInitialized = false;
		fee = _fee;
	}

	function init(uint256 amount, SharedStructs.PositionType position)
		public
		payable
		returns (bool)
	{
		require(!isInitialized, 'Init should only be called once');

		uint256 price = priceOracle.getLatestPrice();
		uint256 leftover = amount % price;
		// TODO: I think this can be solved better if you just rescale the numbers
		uint256 rawDeposited = amount - leftover;
		uint256 deposited = _subtractFee(rawDeposited);
		lastPrice = price;
		isInitialized = true;

		poolState.price = price;
		poolState.longRedeemPrice = price;
		poolState.shortRedeemPrice = price;

		if (position == SharedStructs.PositionType.LONG) {
			require(
				chipToken.transferFrom(msg.sender, address(this), rawDeposited),
				'Transfer of chip token failed'
			);
			_createPosition(
				SharedStructs.PositionType.LONG,
				price,
				deposited.increasePrecision(),
				msg.sender
			);
			_createPosition(
				SharedStructs.PositionType.SHORT,
				price,
				deposited.increasePrecision(),
				address(this)
			);
			protocolPosition = SharedStructs.PositionType.SHORT;
		} else if (position == SharedStructs.PositionType.SHORT) {
			require(
				chipToken.transferFrom(msg.sender, address(this), rawDeposited),
				'Transfer of chip token failed'
			);
			_createPosition(
				SharedStructs.PositionType.SHORT,
				price,
				deposited.increasePrecision(),
				msg.sender
			);
			_createPosition(
				SharedStructs.PositionType.LONG,
				price,
				deposited.increasePrecision(),
				address(this)
			);
			protocolPosition = SharedStructs.PositionType.LONG;
		}
		return true;
	}

	function enter(uint256 amount, SharedStructs.PositionType position)
		public
		payable
		returns (bool)
	{
		require(isInitialized, 'call init before enter');

		uint256 price = priceOracle.getLatestPrice();
		uint256 leftover = amount % price;
		// TODO: I think this can be solved better if you just rescale the numbers
		uint256 deposited = _subtractFee(amount - leftover);

		bool isOverwritingProtocol = position == protocolPosition;

		if (isOverwritingProtocol) {
			_createPosition(
				position,
				price,
				deposited.increasePrecision(),
				msg.sender
			);
			_readjustProtocolPosition(deposited, price);
		} else {
			require(false, 'not implemented');
		}
		return true;
	}

	function getUserBalance(address user) public view returns (uint256) {
		// TODO : Update this logic to the new pool design
		uint256 balance = 0;
		for (uint256 i = 0; i < longPositions.length; i++) {
			if (longPositions[i].owner == user) {
				balance += longPositions[i].chipQuantity;
			}
		}

		for (uint256 i = 0; i < shortPositions.length; i++) {
			if (shortPositions[i].owner == user) {
				balance += shortPositions[i].chipQuantity;
			}
		}

		return balance;
	}

	function update() public payable returns (bool) {
		SharedStructs.Rebalance memory rebalance = rebalancePools();
		bool priceMovedAgainstProtocolLong = (protocolPosition ==
			SharedStructs.PositionType.LONG &&
			rebalance.direction == SharedStructs.PriceMovement.DOWN);
		bool priceMovedAgainstProtocolShort = (protocolPosition ==
			SharedStructs.PositionType.SHORT &&
			rebalance.direction == SharedStructs.PriceMovement.UP);

		if (priceMovedAgainstProtocolLong) {
			// protocol has to "mint" new tokens now.
			// currently just "fake" mints, but this will be changed as new tests are implemented
			longPositions.push(
				SharedStructs.Position({
					entryChipQuantity: rebalance.minted,
					entryPrice: rebalance.price,
					chipQuantity: rebalance.minted,
					owner: address(this)
				})
			);
		} else if (priceMovedAgainstProtocolShort) {
			shortPositions.push(
				SharedStructs.Position({
					entryChipQuantity: rebalance.minted,
					entryPrice: rebalance.price,
					chipQuantity: rebalance.minted,
					owner: address(this)
				})
			);
		}

		return true;
	}

	function rebalancePools()
		public
		payable
		returns (SharedStructs.Rebalance memory)
	{
		uint256 price = priceOracle.getLatestPrice();

		uint256 currentPrice = price;
		uint256 oldPrice = lastPrice;

		poolState = SimpleRebalanceHelper.rebalancePools(price, poolState);

		lastPrice = price;

		return
			RebalancePoolHelper.rebalancePools(
				currentPrice,
				oldPrice,
				protocolPosition,
				longPositions,
				shortPositions
			);
	}

	function getShorts() public view returns (SharedStructs.Position[] memory) {
		return shortPositions;
	}

	function getLongs() public view returns (SharedStructs.Position[] memory) {
		return longPositions;
	}

	function getPoolState()
		public
		view
		returns (SharedStructs.PoolState memory)
	{
		return poolState;
	}

	function _subtractFee(uint256 amount) private view returns (uint256) {
		if (fee != 0) {
			uint256 scaledFeeAmount = amount.increasePrecision() * fee;
			// TODO: Constants like thesse should be abstracted away
			uint256 normalizedFeeAmount = scaledFeeAmount / 10_000;
			uint256 deposited = amount.increasePrecision() -
				normalizedFeeAmount;

			return deposited.normalizeNumber();
		}
		return amount;
	}

	function _createPosition(
		SharedStructs.PositionType position,
		uint256 price,
		uint256 deposited,
		address owner
	) private returns (uint256) {
		uint256 mintedTokens = deposited.normalizeNumber() / price;
		SharedStructs.Position memory newPosition = SharedStructs.Position({
			entryPrice: price,
			entryChipQuantity: deposited,
			chipQuantity: deposited,
			owner: owner
		});

		if (position == SharedStructs.PositionType.LONG) {
			longCfd.exchange(mintedTokens, owner);
			longPositions.push(newPosition);
			poolState.longPoolSize += deposited;
		} else if (position == SharedStructs.PositionType.SHORT) {
			shortCfd.exchange(mintedTokens, owner);
			shortPositions.push(newPosition);
			poolState.shortPoolSize += deposited;
		}
		return 0;
	}

	function _readjustProtocolPosition(uint256 amount, uint256 price)
		private
		returns (bool)
	{
		bool isProtocolLong = protocolPosition ==
			SharedStructs.PositionType.LONG;
		SharedStructs.Position[] storage protocolPositionsPool = (
			isProtocolLong ? longPositions : shortPositions
		);

		for (uint256 i = 0; i < protocolPositionsPool.length; i++) {
			bool isProtocol = protocolPositionsPool[i].owner == address(this);

			if (isProtocol) {
				protocolPositionsPool[i] = RebalancePoolHelper
					.rebalanceProtocolExposure(
						protocolPositionsPool[i],
						amount,
						price,
						amount.increasePrecision(),
						chipToken,
						address(treasury),
						isProtocolLong
					);

				if (protocolPositionsPool[i].chipQuantity == 0) {
					protocolPositionsPool.remove(i);
				}
			}
		}

		uint256 poolBalance = PositionHelper.getPoolBalance(
			SharedStructs.PriceMovement.DOWN,
			longPositions,
			shortPositions
		);
		bool protocolHasToCreatePosition = 0 < poolBalance;

		if (protocolHasToCreatePosition && !isProtocolLong) {
			_createPosition(
				SharedStructs.PositionType.LONG,
				price,
				poolBalance,
				address(this)
			);
		} else if (protocolHasToCreatePosition && isProtocolLong) {
			require(false, 'not implemented');
		}

		return true;
	}
}
