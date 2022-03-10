import { BigNumber } from "@ethersproject/bignumber";

interface Positions {
  entryPrice: BigNumber;
  chipQuantity: BigNumber;
  owner: string;
}

export function sumChipQuantity(item: Positions[]): BigNumber {
  return item.map((item) => item.chipQuantity).reduce((a, b) => a.add(b));
}
