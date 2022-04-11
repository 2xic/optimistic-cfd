//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockStableCoin is ERC20 {
	constructor() ERC20('StableCoin', 'StableU') {}

	function mint(address target, uint256 amount) public {
		_mint(target, amount);
	}
}
