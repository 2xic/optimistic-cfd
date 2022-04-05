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
import {SimpleRebalanceHelper} from './helpers/SimpleRebalanceHelper.sol';
import {MathHelper} from './helpers/MathHelper.sol';
import {ExchangeHelper} from './helpers/ExchangeHelper.sol';
import {SharedStructsHelper} from './helpers/SharedStructsHelper.sol';
import {PoolStateHelper} from './helpers/PoolStateHelper.sol';

contract Pool {
	using MathHelper for uint256;
	using ExchangeHelper for uint256;
	using SimpleRebalanceHelper for SharedStructs.PoolState;
	using SharedStructsHelper for SharedStructs.PositionType;
	using PoolStateHelper for SharedStructs.PoolState;

	SharedStructs.PoolState private poolState;
	uint256 private fee;

	IPriceOracle private priceOracle;
	IERC20 private chipToken;
	EthLongCfd private longCfd;
	EthShortCfd private shortCfd;
	Treasury private treasury;

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
		fee = _fee;
	}

	function init(uint256 amount, SharedStructs.PositionType userPosition)
		public
		payable
	{
		require(!poolState.isInitialized, 'Init should only be called once');

		uint256 price = priceOracle.getLatestPrice();
		uint256 rawDeposited = ExchangeHelper.getExchangedAmount(price, amount);
		uint256 deposited = _subtractFee(rawDeposited);

		poolState.price = price;
		poolState.longRedeemPrice = price;
		poolState.shortRedeemPrice = price;
		poolState.isInitialized = true;

		_transferChipTokensToContract(rawDeposited);

		_createPosition(
			userPosition,
			price,
			deposited.increasePrecision(),
			msg.sender
		);
		_createPosition(
			userPosition.getOppositePosition(),
			price,
			deposited.increasePrecision(),
			address(this)
		);
	}

	function enter(uint256 amount, SharedStructs.PositionType userPosition)
		public
		payable
	{
		require(poolState.isInitialized, 'call init before enter');

		uint256 price = priceOracle.getLatestPrice();
		uint256 rawDeposited = ExchangeHelper.getExchangedAmount(price, amount);
		uint256 deposited = _subtractFee(rawDeposited);

		_transferChipTokensToContract(rawDeposited);

		_createPosition(
			userPosition,
			price,
			deposited.increasePrecision(),
			msg.sender
		);

		poolState = SimpleRebalanceHelper.repositionPool(
			userPosition,
			deposited.increasePrecision(),
			poolState
		);

		rebalance();
	}

	function rebalance() public payable {
		uint256 price = priceOracle.getLatestPrice();

		poolState = SimpleRebalanceHelper.rebalancePools(price, poolState);
		poolState = SimpleRebalanceHelper.rebalanceProtocol(price, poolState);

		poolState.price = price;
	}

	function getUserBalance(SharedStructs.PositionType position)
		public
		view
		returns (uint256)
	{
		if (position == SharedStructs.PositionType.SHORT) {
			uint256 shortBalance = shortCfd.balanceOf(msg.sender);
			return poolState.shortRedeemPrice * shortBalance;
		} else {
			uint256 longBalance = longCfd.balanceOf(msg.sender);
			return poolState.longRedeemPrice * longBalance;
		}
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
			uint256 scaledAmount = amount.increasePrecision();
			uint256 scaledFeeAmount = scaledAmount * fee;
			uint256 normalizedFeeAmount = scaledFeeAmount.normalizeNumber();
			uint256 deposited = scaledAmount - normalizedFeeAmount;

			return deposited.normalizeNumber();
		}
		return amount;
	}

	function _transferChipTokensToContract(uint256 amount) private {
		require(
			chipToken.transferFrom(msg.sender, address(this), amount),
			'Transfer of chip token failed'
		);
	}

	function _createPosition(
		SharedStructs.PositionType position,
		uint256 price,
		uint256 deposited,
		address owner
	) private {
		uint256 mintedTokens = ExchangeHelper.getMinted(
			price,
			deposited.normalizeNumber()
		);

		if (position == SharedStructs.PositionType.LONG) {
			poolState.longSupply += longCfd.exchange(mintedTokens, owner);
			poolState.longPoolSize += deposited;
		} else if (position == SharedStructs.PositionType.SHORT) {
			poolState.shortSupply += shortCfd.exchange(mintedTokens, owner);
			poolState.shortPoolSize += deposited;
		}

		if (owner == address(this)) {
			bool canPositionBeCreated = poolState.canProtocolEnterPosition(
				position
			);
			require(canPositionBeCreated, 'Invalid state');

			poolState.protocolState.position = position;
			poolState.protocolState.size += deposited;
			poolState.protocolState.cfdSize += mintedTokens;
		}
	}
}
