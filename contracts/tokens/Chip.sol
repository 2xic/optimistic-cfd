//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Chip is ERC20 {
	address private owner;

	constructor(address _owner) ERC20('Chip', 'C') {
		owner = _owner;
	}

	function mint(uint256 amount) public payable returns (uint256) {		
		require(msg.sender == owner, 'Only owner can mint tokens');
		require(amount > 0, 'Amount not specified');
		_mint(owner, amount);
		return amount;
	}

	function burn(uint256 amount) public payable returns (uint256) {
		require(msg.sender == owner, 'Only owner can burn tokens');
		require(amount > 0, 'Amount not specified');
		_burn(owner, amount);
		return amount;
	}

	function transferToken(uint256 amount, address target)
		public
		payable
		returns (uint256)
	{
		require(msg.sender == owner, 'Only owner can transfer minted tokens');
		transfer(target, amount);
		return amount;
	}

	function transferOwnerShip(address newOwner) public payable returns (bool) {
		require(owner == msg.sender, 'Only owner can change ownership');
		owner = newOwner;

		return true;
	}
}
