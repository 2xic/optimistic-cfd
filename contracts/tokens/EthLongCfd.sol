//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract EthLongCfd is ERC20 {
	address private owner;

	constructor(address _owner) ERC20('EthLongCfd', 'ETHLCDF') {
		owner = _owner;
	}

	function mint(uint256 amount, address receiver)
		public
		
		returns (uint256)
	{
		require(
			msg.sender == owner,
			'Only the owner contract should call this function'
		);
		require(amount > 0, 'Amount not specified');
		require(amount < 2**128, 'Amount overflow');
		_mint(receiver, amount);

		return amount;
	}

	function burn(uint256 amount, address account) public  {
		_burn(account, amount);
	}

	function transferOwnerShip(address newOwner) public  returns (bool) {
		require(
			msg.sender == owner,
			'Only the owner contract should call this function'
		);
		owner = newOwner;

		return true;
	}
}
