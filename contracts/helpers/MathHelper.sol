//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library MathHelper {
    uint256 private constant EXPONENT = 1000;
    uint256 private constant PERCENTAGE_SCALE = 100;

    function relativeDivide(uint256 a, uint256 b)
        public
        pure
        returns (uint256)
    {
        if (b < a) {
            return
                (a *
                    EXPONENT *
                    PERCENTAGE_SCALE -
                    b *
                    EXPONENT *
                    PERCENTAGE_SCALE) / (b * EXPONENT);
        } else {
            return
                (b *
                    EXPONENT *
                    PERCENTAGE_SCALE -
                    a *
                    EXPONENT *
                    PERCENTAGE_SCALE) / (a * EXPONENT);
        }
    }

    function multiplyPercentage(uint256 number, uint256 scaledPercentage)
        public
        pure
        returns (uint256)
    {
        return
            (number * (PERCENTAGE_SCALE + scaledPercentage)) / PERCENTAGE_SCALE;
    }

    function increasePrecision(uint256 number) public pure returns (uint256) {
        return number * EXPONENT;
    }

    function normalizeNumber(uint256 number) public pure returns (uint256) {
        return number / EXPONENT;
    }
}
