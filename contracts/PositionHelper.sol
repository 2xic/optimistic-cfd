import {SharedStructs} from "./structs/Postion.sol";

library PositionHelper {
    struct Positon {
        uint256 entryPrice;
        uint256 chipQuantity;
        address owner;
    }

    struct Storage {
        Positon[] Positons;
    }

    function remove(
        Storage storage self, 
        uint256 index
    )
        public
    {
        require(index >= self.Positons.length, "Bad input");

        for (uint256 i = index; i < self.Positons.length - 1; i++) {
            self.Positons[i] = self.Positons[i + 1];
        }
        delete self.Positons[index];
    }
}
