import { Signer } from "ethers";

export async function getAddressSigner(contract: { signer: Signer }) {
  return contract.signer.getAddress();
}
