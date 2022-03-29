import { BigNumber } from 'ethers';
import { Pool } from '../../typechain/Pool';

interface State {
  longSupply: BigNumber;
  shortSupply: BigNumber;
  longPoolSize: BigNumber;
  shortPoolSize: BigNumber;
  price: BigNumber;
  longRedeemPrice: BigNumber;
  shortRedeemPrice: BigNumber;
  protocolState: {
    position: number;
    size: BigNumber;
    cfdSize: BigNumber;
  };
}

export async function getPoolState(pool: Pool): Promise<State> {
  const poolState = await pool.getPoolState();
  const keys = [...Object.keys(poolState)].filter((item) => {
    return isNaN(Number(item));
  });

  const state: Record<string, BigNumber> = {};
  keys.forEach((key) => {
    state[key] = (poolState as any)[key];
  });

  return state as unknown as State;
}
