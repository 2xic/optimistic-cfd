import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Chip } from '../typechain';
import { decodeBoolAbi } from './helpers/decodeAbi';
import { deployContract } from './helpers/deployContract';
import { getAddressSigner } from './helpers/getAddressSigner';

describe('Chip', function () {
  let owner: SignerWithAddress;
  let randomAddress: SignerWithAddress;
  let chipToken: Chip;

  beforeEach(async () => {
    [owner, randomAddress] = await ethers.getSigners();

    const ChipTokenContract = await ethers.getContractFactory('Chip');
    chipToken = await ChipTokenContract.deploy(await owner.getAddress());
  });

  it('Should be possible to mint new tokens', async function () {
    const { chipToken, coreContract } = await deployContract();
    await chipToken.mint(100);

    const balance = await chipToken.balanceOf(
      await coreContract.signer.getAddress()
    );
    expect(balance).to.equal(100);
  });

  it('Should be possible to burn new tokens', async function () {
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

  it('Should be possible to exchange $c for $cfdLong', async () => {
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

  it('Should be possible to exchange $c for $cfdShort', async () => {
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

  it('only be possible for the owner contract to mint tokens', async () => {
    await expect(chipToken.connect(randomAddress).mint(100)).to.be.revertedWith(
      'Only owner can mint tokens'
    );
    await chipToken.connect(owner).mint(100);
  });

  it('only be possible for the owner contract to burn tokens', async () => {
    await chipToken.connect(owner).mint(100);

    await expect(chipToken.connect(randomAddress).burn(100)).to.be.revertedWith(
      'Only owner can burn tokens'
    );

    chipToken.connect(owner).burn(100);
  });

  it.skip('should be possible to exchange other stablecoins for chip token', () => {});
});
