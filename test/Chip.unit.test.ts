import { expect } from "chai";
import { ethers } from "hardhat";
import { deployContract } from "./helpers/deployContract";

describe("Chip", function () {
  it("Should be possible to mint new tokens", async function () {
    const { chipToken, coreContract } = await deployContract();
    await chipToken.mint(100);

    const balance = await chipToken.balanceOf(
      await coreContract.signer.getAddress()
    );
    expect(balance).to.equal(100);
  });

  it("Should be possible to burn new tokens", async function () {
    const { chipToken, coreContract } = await deployContract();
    await chipToken.mint(100);
    await expect(
      await chipToken.balanceOf(await coreContract.signer.getAddress())
    ).to.equal(100);

    await chipToken.burn(100);
    await expect(
      await chipToken.balanceOf(await coreContract.signer.getAddress())
    ).to.equal(0);
  });

  it.skip('Should only be possible for the "core" contract to mint or burn chip tokens', async () => {
    const { chipToken, randomAddress } = await deployContract();
    await chipToken.connect(randomAddress).mint(100);

    const balance = await chipToken.balanceOf(chipToken.address);
    expect(balance).to.equal(0);
  });

  it("Should be possible to exchange $c for $cfdlong", async () => {
    const { chipToken, coreContract, pool, longCfdTOken } = await deployContract();
    await chipToken.mint(100);

    const coreContractBalance = await chipToken.balanceOf(
      await coreContract.signer.getAddress()
    );
    expect(coreContractBalance).to.equal(100);

    const { data } = await chipToken
      .connect(coreContract.signer)
      .approve(pool.address, 100);

    expect(
      ethers.utils.defaultAbiCoder
        .decode(["bool"], ethers.utils.hexDataSlice(data, 4))
        .toString()
    ).to.equal("true");

    await pool.connect(coreContract.signer).init(1, 0);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      await coreContract.signer.getAddress()
    );
    expect(updatedCoreContractBalance).to.equal(99);

    const longCfdTOkenBalance = await longCfdTOken.balanceOf(
      await coreContract.signer.getAddress()
    );
    expect(longCfdTOkenBalance).to.equal(1);
  });

  it.skip("Should be possible to exchange $c for $cfdshort", () => {
    expect.fail("Not implemented");
  });

  it.skip("should take an 0.3% fee when entering an synehtetic position", () => {
    expect.fail("Not implemented");
  });

  it.skip("should take an 0.3% fee on when exiting an synehtetic position", () => {
    expect.fail("Not implemented");
  });
});
