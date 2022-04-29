pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {EthShortCfd} from 'contracts/tokens/EthShortCfd.sol';
import {RandomAddress} from 'contracts/mocking/RandomAddress.sol';

contract EthShortCfdTest is Test {
	RandomAddress randomAddress;

	function setUp() public {
		randomAddress = new RandomAddress();
	}

	function testFailMintWithNonOwnerAddress() public {
		EthShortCfd ethShortCfd = new EthShortCfd(address(randomAddress));
		ethShortCfd.mint(100, address(this));
	}


	function testMintWithOwnerAddress() public {
		EthShortCfd ethShortCfd = new EthShortCfd(address(this));
		ethShortCfd.mint(100, address(this));
	}
}
