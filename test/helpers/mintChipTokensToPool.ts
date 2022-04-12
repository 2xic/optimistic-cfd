import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, Signer } from 'ethers';
import { Chip, Pool } from '../../typechain';
import { decodeBoolAbi } from './decodeAbi';

export async function mintTokenToPool({
  chipToken,
  pool,
  coreContractSignerAddress,
  receivers: inputReceivers,
}: {
  chipToken: Chip;
  pool: Pool;
  coreContractSignerAddress: string;
  receivers?: Array<{ amount: BigNumber; address: SignerWithAddress | Signer }>;
}): Promise<void> {
  const receivers = (inputReceivers || []).concat([
    {
      address: pool.signer,
      amount: BigNumber.from(100),
    },
  ]);

  const amount = (receivers || [])
    .reduce((a, b) => a.add(b.amount), BigNumber.from(0))
    .toNumber();

  await chipToken.connect(pool.signer).mint(amount);

  const coreContractBalance = await chipToken.balanceOf(
    coreContractSignerAddress
  );
  expect(coreContractBalance).to.equal(amount);

  await Promise.all(
    receivers.map(async ({ address, amount }) => {
      await chipToken
        .connect(pool.signer)
        .transferToken(amount, await address.getAddress());

      const { data } = await chipToken
        .connect(address)
        .approve(pool.address, amount);

      expect(decodeBoolAbi({ data })).to.equal(true);
    })
  );

  await chipToken.connect(pool.signer).transferOwnerShip(pool.address);
}
