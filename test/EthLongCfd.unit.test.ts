import { expect } from "chai";
import { ethers } from "hardhat";

describe("EthLongCfd", () => {
  it("only be possible for the owner contract to mint tokens", async () => {
    const [owner, randomAddress] = await ethers.getSigners();

    const EthLongCfdTokenContract = await ethers.getContractFactory(
      "EthLongCfd"
    );
    const ethLongCfdToken = await EthLongCfdTokenContract.deploy(
      await owner.getAddress()
    );

    await expect(
      ethLongCfdToken
        .connect(randomAddress)
        .exchange(100, randomAddress.address)
    ).to.be.revertedWith("Only the owner contract should call this function");

    await ethLongCfdToken.connect(owner).exchange(100, randomAddress.address);
  });
});
