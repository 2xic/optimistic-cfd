import { BigNumber } from 'ethers';

interface Positions {
  entryPrice: BigNumber;
  chipQuantity: BigNumber;
  owner: string;
}

export function sumChipQuantity(
  item: Positions[],
  options?:
    | {
        address: string;
      }
    | undefined
): BigNumber {
  return item
    .filter((item) => {
      if (options && options.address) {
        return options.address === item.owner;
      }
      return true;
    })
    .map((item) => item.chipQuantity)
    .reduce((a, b) => a.add(b), BigNumber.from(0));
}
