import { expect } from "chai";
import { deployContract } from "./helpers/deployChip";

describe("Chip", function () {
  it("Should be possible to mint new tokens", async function () {
    const { chipToken, coreContract } = await deployContract();
    await chipToken.connect(coreContract).mint(100);

    const balance = await chipToken.balanceOf(chipToken.address);
    expect(balance).to.equal(100);
  });

  it("Should be possible to burn new tokens", async function () {
    const { chipToken, coreContract } = await deployContract();
    await chipToken.connect(coreContract).mint(100);
    await expect(await chipToken.balanceOf(chipToken.address)).to.equal(100);

    await chipToken.connect(coreContract).burn(100);
    await expect(await chipToken.balanceOf(chipToken.address)).to.equal(0);
  });

  it('Should only be possible for the "core" contract to mint or burn chip tokens', async () => {
    const { chipToken, randomAddress } = await deployContract();
    await chipToken.connect(randomAddress).mint(100);

    const balance = await chipToken.balanceOf(chipToken.address);
    expect(balance).to.equal(0);
  });

  it("Should be possible to exchange $c for $cfdlong", () => {
    expect.fail("Not implemented");
  });

  it("Should be possible to exchange $c for $cfdshort", () => {
    expect.fail("Not implemented");
  });

  it("should take an 0.3% fee when entering an synehtetic position", () => {
    expect.fail("Not implemented");
  });

  it("should take an 0.3% fee on when exiting an synehtetic position", () => {
    expect.fail("Not implemented");
  });
});
