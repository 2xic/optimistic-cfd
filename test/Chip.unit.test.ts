import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { Chip, MockStableCoin } from '../typechain';
import { deployContract } from './helpers/deployContract';
import { getAddressSigner } from './helpers/getAddressSigner';

describe('Chip', function () {
  let owner: SignerWithAddress;
  let randomAddress: SignerWithAddress;
  let chipToken: Chip;
  let stableCoin: MockStableCoin;

  beforeEach(async () => {
    [owner, randomAddress] = await ethers.getSigners();

    const ChipTokenContract = await ethers.getContractFactory('Chip');
    const StableCoin = await ethers.getContractFactory('MockStableCoin');
    stableCoin = await StableCoin.deploy();

    chipToken = await ChipTokenContract.deploy(
      await owner.getAddress(),
      stableCoin.address
    );
  });

  it('Should be possible to mint new tokens', async function () {
    await chipToken.mint(100);

    const balance = await chipToken.balanceOf(await owner.getAddress());
    expect(balance).to.equal(100);
  });

  it('Should be possible to burn new tokens', async function () {
    await chipToken.mint(100);
    expect(await getBalanceOfOwner()).to.equal(100);

    await chipToken.burn(100);
    expect(await getBalanceOfOwner()).to.equal(0);
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

    await chipToken.connect(coreContract.signer).approve(pool.address, 100);
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

    await chipToken.connect(coreContract.signer).approve(pool.address, 100);
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

  it('should be possible to exchange other stablecoins for chip token', async () => {
    await chipToken.connect(owner).mint(100);
    await stableCoin.mint(randomAddress.address, 100);

    await stableCoin
      .connect(randomAddress)
      .increaseAllowance(chipToken.address, 10000);

    await chipToken.connect(randomAddress).exchange(100);

    expect((await chipToken.balanceOf(randomAddress.address)).toString()).to.eq(
      '100'
    );
  });

  async function getBalanceOfOwner(): Promise<BigNumber> {
    return await chipToken.balanceOf(await owner.getAddress());
  }
});
