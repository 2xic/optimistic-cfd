import { expect } from "chai";
import { ethers } from "hardhat";
import { decodeBoolAbi } from "./helpers/decodeAbi";
import { deployContract } from "./helpers/deployContract";
import { getAddressSigner } from "./helpers/getAddressSigner";

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
    const { chipToken, coreContract, pool, longCfdTOken, shortCfdToken } =
      await deployContract();
    const coreContractSignerAddress = await getAddressSigner(coreContract);
    await chipToken.mint(100);

    const coreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(coreContractBalance).to.equal(100);

    const { data } = await chipToken
      .connect(coreContract.signer)
      .approve(pool.address, 100);

    expect(decodeBoolAbi({ data })).to.equal(true);

    await pool.connect(coreContract.signer).init(75, 0);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(25);

    const longCfdTOkenBalance = await longCfdTOken.balanceOf(
      coreContractSignerAddress
    );
    expect(longCfdTOkenBalance).to.equal(15);

    const shortCfdTokenBalance = await shortCfdToken.balanceOf(pool.address);
    expect(shortCfdTokenBalance).to.equal(15);
  });

  it("Should be possible to exchange $c for $cfdshort", async () => {
    const { chipToken, coreContract, pool, longCfdTOken, shortCfdToken } =
      await deployContract();
    const coreContractSignerAddress = await getAddressSigner(coreContract);
    await chipToken.mint(100);

    const coreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(coreContractBalance).to.equal(100);

    const { data } = await chipToken
      .connect(coreContract.signer)
      .approve(pool.address, 100);

    expect(decodeBoolAbi({ data })).to.equal(true);

    await pool.connect(coreContract.signer).init(75, 1);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(25);

    const longCfdTOkenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTOkenBalance).to.equal(15);

    const shortCfdTokenBalance = await shortCfdToken.balanceOf(
      coreContractSignerAddress
    );
    expect(shortCfdTokenBalance).to.equal(15);
  });

  it("only be possible for the owner contract to mint tokens", async () => {
    const [owner, randomAddress] = await ethers.getSigners();

    const ChipTokenContract = await ethers.getContractFactory("Chip");
    const chipToken = await ChipTokenContract.deploy(await owner.getAddress());

    await expect(chipToken.connect(randomAddress).mint(100)).to.be.revertedWith(
      "Only owner can mint tokens"
    );
    await chipToken.connect(owner).mint(100);
  });

  it("only be possible for the owner contract to burn tokens", async () => {
    const [owner, randomAddress] = await ethers.getSigners();

    const ChipTokenContract = await ethers.getContractFactory("Chip");
    const chipToken = await ChipTokenContract.deploy(await owner.getAddress());

    await chipToken.connect(owner).mint(100);

    await expect(chipToken.connect(randomAddress).burn(100)).to.be.revertedWith(
      "Only owner can burn tokens"
    );

    chipToken.connect(owner).burn(100);
  });
});
