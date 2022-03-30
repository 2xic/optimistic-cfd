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

contract Pool {
	using MathHelper for uint256;
	using ExchangeHelper for uint256;
	using SimpleRebalanceHelper for SharedStructs.PoolState;
	using SharedStructsHelper for SharedStructs.PositionType;

	SharedStructs.PoolState private poolState;

	IPriceOracle private priceOracle;
	IERC20 private chipToken;
	EthLongCfd private longCfd;
	EthShortCfd private shortCfd;
	Treasury private treasury;

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
			userPosition.getOppositePositon(),
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

		update();
	}

	function getUserBalance(address user) public view returns (uint256) {
		uint256 shortBalance = shortCfd.balanceOf(user);
		uint256 longBalance = longCfd.balanceOf(user);

		if (0 < shortBalance) {
			return poolState.shortRedeemPrice * shortBalance;
		} else {
			return poolState.longRedeemPrice * longBalance;
		}
	}

	// TODO: This function should be renamed.
	// 		It's the function that should be called on a oracle update, but it should also be called when a user enters a trade
	function update() public payable {
		uint256 price = priceOracle.getLatestPrice();

		poolState = SimpleRebalanceHelper.rebalancePools(price, poolState);
		poolState = SimpleRebalanceHelper.rebalanceProtcol(price, poolState);

		poolState.price = price;
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

	function _transferChipTokensToContract(
		uint256 amount
	) private {
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
			bool canPositionBeCreated = poolState.protocolState.position ==
				position ||
				poolState.protocolState.size == 0;
			require(canPositionBeCreated, 'Invalid state');

			poolState.protocolState.position = position;
			poolState.protocolState.size += deposited;
			poolState.protocolState.cfdSize += mintedTokens;
		}
	}
}
