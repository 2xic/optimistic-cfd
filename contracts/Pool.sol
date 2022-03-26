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
	using RebalancePoolHelper for SharedStructs.Position[];
	using MathHelper for uint256;
	using SimpleRebalanceHelper for SharedStructs.PoolState;

	SharedStructs.PoolState private poolState;

	IPriceOracle private priceOracle;
	IERC20 private chipToken;
	EthLongCfd private longCfd;
	EthShortCfd private shortCfd;
	Treasury private treasury;

/*	bool private isInitialized;
	uint256 private lastPrice;
*/
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
		poolState.isInitialized = false;
		fee = _fee;
	}

	function init(uint256 amount, SharedStructs.PositionType position)
		public
		payable
		returns (bool)
	{
		require(!poolState.isInitialized, 'Init should only be called once');

		uint256 price = priceOracle.getLatestPrice();
		uint256 leftover = amount % price;
		// TODO: I think this can be solved better if you just rescale the numbers
		uint256 rawDeposited = amount - leftover;
		uint256 deposited = _subtractFee(rawDeposited);

		poolState.price = price;
		poolState.longRedeemPrice = price;
		poolState.shortRedeemPrice = price;
		poolState.isInitialized = true;

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
		}
		return true;
	}

	function enter(uint256 amount, SharedStructs.PositionType position)
		public
		payable
		returns (bool)
	{
		require(poolState.isInitialized, 'call init before enter');

		uint256 price = priceOracle.getLatestPrice();
		uint256 leftover = amount % price;
		// TODO: I think this can be solved better if you just rescale the numbers
		uint256 deposited = _subtractFee(amount - leftover);

		require(false, 'not implemented');
		return true;
	}

	function getUserBalance(address user) public view returns (uint256) {
		require(false, 'not implemented');
	}

	function update() public payable returns (bool) {
		uint256 price = priceOracle.getLatestPrice();

		//        poolState = SimpleRebalanceHelper.rebalancePools(price, poolState);
		rebalancePools();
		poolState = SimpleRebalanceHelper.rebalanceProtcol(price, poolState);

		poolState.price = price;

		return true;
	}

	function rebalancePools() public payable returns (bool) {
		uint256 price = priceOracle.getLatestPrice();
		poolState = SimpleRebalanceHelper.rebalancePools(price, poolState);
		return true;
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

	function getPoolState()
		public
		view
		returns (SharedStructs.PoolState memory)
	{
		return poolState;
	}

	function _createPosition(
		SharedStructs.PositionType position,
		uint256 price,
		uint256 deposited,
		address owner
	) private returns (uint256) {
		uint256 mintedTokens = deposited.normalizeNumber() / price;

		if (position == SharedStructs.PositionType.LONG) {
			longCfd.exchange(mintedTokens, owner);
			poolState.longPoolSize += deposited;
		} else if (position == SharedStructs.PositionType.SHORT) {
			shortCfd.exchange(mintedTokens, owner);
			poolState.shortPoolSize += deposited;
		}

		if (owner == address(this)) {
			poolState.protocolState.size += deposited;
			poolState.protocolState.position = position;
		}

		return 0;
	}
}
