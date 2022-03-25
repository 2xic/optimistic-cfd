import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('EthShortCfd', () => {
  it('only be possible for the owner contract to mint tokens', async () => {
    const [owner, randomAddress] = await ethers.getSigners();

    const EthShortCfdTokenContract = await ethers.getContractFactory(
      'EthShortCfd'
    );
    const ethShortCfdToken = await EthShortCfdTokenContract.deploy(
      await owner.getAddress()
    );

    await expect(
      ethShortCfdToken
        .connect(randomAddress)
        .exchange(100, randomAddress.address)
    ).to.be.revertedWith('Only the owner contract should call this function');

    await ethShortCfdToken.connect(owner).exchange(100, randomAddress.address);
  });
});
