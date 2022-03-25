import { BytesLike } from 'ethers';
import { ethers } from 'hardhat';

export function decodeBoolAbi({ data }: { data: BytesLike }): boolean {
  const [response] = ethers.utils.defaultAbiCoder.decode(
    ['bool'],
    ethers.utils.hexDataSlice(data, 4)
  );
  if (typeof response === 'boolean') {
    return response;
  } else {
    throw new Error('Expected boolean ');
  }
}
