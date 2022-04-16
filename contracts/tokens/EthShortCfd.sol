//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract EthShortCfd is ERC20 {
	address private owner;

	constructor(address _owner) ERC20('EthShortCfd', 'ETHSCDF') {
		require(
			_owner != address(0),
			'Cannot use zero address as owner'
		);
		owner = _owner;
	}

	function mint(uint256 amount, address receiver)
		external
		returns (uint256)
	{
		require(
			msg.sender == owner,
			'Only the owner contract should call this function'
		);
		_mint(receiver, amount);

		return amount;
	}

	function burn(uint256 amount, address account) external {
		_burn(account, amount);
	}

	function transferOwnerShip(address newOwner) external returns (bool) {
		require(
			newOwner != address(0),
			'Cannot use zero address as owner'
		);
		require(
			msg.sender == owner,
			'Only the owner contract should call this function'
		);
		owner = newOwner;

		return true;
	}
}
