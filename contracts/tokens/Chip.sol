//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Chip is ERC20 {
	address private owner;
	ERC20 private usdc;

	constructor(address _owner, address _usdc) ERC20('Chip', 'C') {
		owner = _owner;
		usdc = ERC20(_usdc);
	}

	function mint(uint256 amount) public returns (uint256) {
		require(msg.sender == owner, 'Only owner can mint tokens');
		require(amount > 0, 'Amount not specified');
		require(amount < 2**128, 'Amount overflow');
		_mint(owner, amount);
		return amount;
	}

	function burn(uint256 amount) public returns (uint256) {
		require(msg.sender == owner, 'Only owner can burn tokens');
		require(amount > 0, 'Amount not specified');
		_burn(owner, amount);
		return amount;
	}

	function transferToken(uint256 amount, address target)
		public
		returns (uint256)
	{
		require(msg.sender == owner, 'Only owner can transfer minted tokens');
		transfer(target, amount);
		return amount;
	}

	function transferOwnerShip(address newOwner) public returns (bool) {
		require(owner == msg.sender, 'Only owner can change ownership');
		owner = newOwner;

		return true;
	}

	function exchange(uint256 amount) public {
		require(
			usdc.transferFrom(msg.sender, address(this), amount),
			'Transfer of usdc failed'
		);
		_mint(msg.sender, amount);
	}
}
