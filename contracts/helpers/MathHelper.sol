//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library MathHelper {
    uint256 private constant expontent = 1000;

    function relativeDivide(uint256 a, uint256 b)
        public
        pure
        returns (uint256)
    {
        return ((a * expontent - b * expontent) / (a * expontent)) * 100;
    }

    function increasePresiion(uint256 number) public pure returns (uint256) {
        return number * expontent;
    }

    function noramlizeNumber(uint256 number) public pure returns (uint256) {
        return number / expontent;
    }
}
