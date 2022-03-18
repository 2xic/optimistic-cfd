import { expect } from "chai";
import { Chip, CoreContract, Pool } from "../../typechain";
import { decodeBoolAbi } from "./decodeAbi";

export async function mintTokenToPool({
  chipToken,
  coreContract,
  pool,
  coreContractSignerAddress,
}: {
  chipToken: Chip;
  coreContract: CoreContract;
  pool: Pool;
  coreContractSignerAddress: string;
}): Promise<void> {
  await chipToken.mint(100);

  const coreContractBalance = await chipToken.balanceOf(
    coreContractSignerAddress
  );
  expect(coreContractBalance).to.equal(100);

  const { data } = await chipToken
    .connect(coreContract.signer)
    .approve(pool.address, 100);
  expect(decodeBoolAbi({ data })).to.equal(true);
}
