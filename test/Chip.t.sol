pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Chip} from 'contracts/tokens/Chip.sol';
import {RandomAddress} from 'contracts/mocking/RandomAddress.sol';
import {MockStableCoin} from 'contracts/mocking/MockStableCoin.sol';

contract ChipTest is Test {
	RandomAddress randomAddress;
    MockStableCoin mockStableCoin;
    Chip chip;

	function setUp() public {
		randomAddress = new RandomAddress();
        mockStableCoin = new MockStableCoin();
        chip = new Chip(address(this), address(mockStableCoin));
	}

	function testShouldBePossibleToMint() public {
		chip.mint(100);
        require(chip.balanceOf(address(this)) == 100, 'minting failed');
	}

    function testShouldBePossibleToBurn() public {
		chip.mint(100);
        require(chip.balanceOf(address(this)) == 100, 'minting failed');

        chip.burn(100);
        require(chip.balanceOf(address(this)) == 0, 'burn failed');
    }

    function testShouldBePossibleToExchangeStableCoinForChipToken() public {
		chip.mint(100);
        mockStableCoin.mint(address(this), 100);

        mockStableCoin.increaseAllowance(address(chip), 10000);
        chip.exchange(100);
    }
}
