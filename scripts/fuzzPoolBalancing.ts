import { deployContract } from '../test/helpers/deployContract';
import { mintTokenToPool } from '../test/helpers/mintChipTokensToPool';

import { expect } from 'chai';
import { getAddressSigner } from '../test/helpers/getAddressSigner';
import { sumChipQuantity } from '../test/helpers/sumPositions';
import { Position } from '../test/types/Position';

async function main() {
  let rounds = 0;
  while (true) {
    const { chipToken, randomAddress, coreContract, pool, priceConsumer } =
      await deployContract();
    const coreContractSignerAddress = await getAddressSigner(coreContract);
    await mintTokenToPool({
      chipToken,
      coreContract,
      pool,
      coreContractSignerAddress,
    });

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.LONG);

    await chipToken.connect(pool.signer).approve(pool.address, 100);
    expect(await chipToken.balanceOf(pool.address)).to.equal(50);

    await priceConsumer.connect(coreContract.signer).setPrice(5);
    await pool.connect(pool.signer).update();
    await pool
      .connect(randomAddress)
      .enter(parseInt((10 + Math.random() * 100).toString()), Position.SHORT);

    expect(sumChipQuantity(await pool.getShorts())).to.equal(
      sumChipQuantity(await pool.getLongs())
    );

    if (rounds % 10 === 0) {
      console.log(rounds);
    }

    rounds++;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
