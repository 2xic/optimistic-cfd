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

export function decodeUint256Abi({ data }: { data: BytesLike }): number {
  const [response] = ethers.utils.defaultAbiCoder.decode(
    ['uint256'],
    ethers.utils.hexDataSlice(data, 4)
  );
  if (typeof response === 'number') {
    return response;
  } else {
    throw new Error(`Expected number, got ${response}`);
  }
}
