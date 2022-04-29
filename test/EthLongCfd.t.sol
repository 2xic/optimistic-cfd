pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {EthLongCfd} from 'contracts/tokens/EthLongCfd.sol';
import {RandomAddress} from 'contracts/mocking/RandomAddress.sol';

contract EthShortCfdTest is Test {
	RandomAddress randomAddress;

	function setUp() public {
		randomAddress = new RandomAddress();
	}

	function testFailMintWithNonOwnerAddress() public {
		EthLongCfd ethLongCfd = new EthLongCfd(address(randomAddress));
		ethLongCfd.mint(100, address(this));
	}


	function testMintWithOwnerAddress() public {
		EthLongCfd ethLongCfd = new EthLongCfd(address(this));
		ethLongCfd.mint(100, address(this));
	}
}
