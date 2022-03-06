import { ethers } from "hardhat";

export async function deployContract() {
  const ChipTokenContract = await ethers.getContractFactory("Chip");
  const chipToken = await ChipTokenContract.deploy();
  await chipToken.deployed();

  // eslint-disable-next-line no-unused-vars
  const [_owner, coreContract, randomAddress] = await ethers.getSigners();

  return {
    chipToken,
    coreContract,
    randomAddress,
  };
}
