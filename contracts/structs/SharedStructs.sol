//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library SharedStructs {
	struct Position {
		uint256 entryPrice;
		uint256 entryChipQuantity;
		uint256 chipQuantity;
		address owner;
	}

	struct PoolState {
		uint256 longSupply;
		uint256 shortSupply;
		uint256 longPoolSize;
		uint256 shortPoolSize;
		uint256 price;
		uint256 longRedeemPrice;
		uint256 shortRedeemPrice;

		ProtcolState protocolState;
		bool isInitialized;
	}

	struct ProtcolState {
		PositionType position;
		uint256 size;
		uint256 cfdSize;
	}

	struct Rebalance {
		PriceMovement direction;
		uint256 minted;
		uint256 price;
	}

	enum PositionType {
		LONG,
		SHORT
	}

	enum PriceMovement {
		DOWN,
		UP,
		STABLE
	}
}
