import { expect } from 'chai';
import { deployContract, DeployOptions } from './helpers/deployContract';
import { getAddressSigner } from './helpers/getAddressSigner';
import { Position } from './types/Position';
import forEach from 'mocha-each';
import { mintTokenToPool } from './helpers/mintChipTokensToPool';
import { getPoolState } from './helpers/getPoolState';
import { Chip, CoreContract, MockPriceOracle, Pool } from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, Contract } from 'ethers';

describe('Pool', () => {
  let chipToken: Chip;
  let randomAddress: SignerWithAddress;
  let coreContract: CoreContract;
  let pool: Pool;
  let priceConsumer: MockPriceOracle;
  let treasury: Contract;

  async function deploy(deploymentOptions?: DeployOptions) {
    const options = await deployContract(deploymentOptions);

    chipToken = options.chipToken;
    randomAddress = options.randomAddress;
    coreContract = options.coreContract;
    pool = options.pool;
    priceConsumer = options.priceConsumer;
    treasury = options.treasury;

    const coreContractSignerAddress = await getAddressSigner(coreContract);
    await mintTokenToPool({
      chipToken,
      coreContract,
      pool,
      coreContractSignerAddress,
      receivers: [
        {
          address: randomAddress,
          amount: BigNumber.from(100),
        },
      ],
    });
  }

  beforeEach(async () => {
    await deploy();
  });

  it('should not be possible to call the init function multiple times', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);

    await expect(
      pool.connect(coreContract.signer).init(50, Position.SHORT)
    ).to.be.revertedWith('Init should only be called once');
  });

  forEach([[Position.SHORT], [Position.LONG]]).it(
    'should correctly adjust the pools after a price move against the protocol position',
    async (userPosition) => {
      const coreContractSignerAddress = await getAddressSigner(coreContract);

      await priceConsumer.connect(coreContract.signer).setPrice(10);
      await pool.connect(coreContract.signer).init(50, userPosition);

      const updatedCoreContractBalance = await chipToken.balanceOf(
        coreContractSignerAddress
      );
      expect(updatedCoreContractBalance).to.equal(50);

      expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
      expect((await getPoolState(pool)).longPoolSize).to.eq(50000);

      if (userPosition === Position.SHORT) {
        await priceConsumer.connect(coreContract.signer).setPrice(5);
      } else {
        await priceConsumer.connect(coreContract.signer).setPrice(15);
      }

      await pool.connect(coreContract.signer).rebalance();

      expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
      expect((await getPoolState(pool)).longPoolSize).to.eq(75000);
    }
  );

  it.skip('should keep the pools balanced after priced move with the protocol', async () => {
    const userPosition = Position.LONG;

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, userPosition);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);

    // Protocol will be short, and will therefore "burn" the outstanding
    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(25000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(25000);

    await priceConsumer.connect(coreContract.signer).setPrice(15);

    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(75000);
  });

  it('should burn minted $c if fresh users join the pool', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.LONG);
    await pool.connect(randomAddress).enter(50, Position.SHORT);

    const coreContractSignerAddress = await getAddressSigner(coreContract);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);

    expect((await getPoolState(pool)).protocolState.size).to.eq(0);
  });

  it('should not be possible to call enter before init', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await expect(
      pool.connect(randomAddress).enter(50, Position.SHORT)
    ).to.be.revertedWith('call init before enter');
  });

  it('should correctly adjust the short redeem price', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);

    await pool.connect(coreContract.signer).init(50, Position.LONG);
    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(5);
    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.position).to.eq(
      Position.SHORT
    );

    await pool.connect(randomAddress).enter(50, Position.SHORT);

    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(0);
    expect((await getPoolState(pool)).protocolState.size).to.eq(0);
    expect((await getPoolState(pool)).longSupply).to.eq(5);
    expect((await getPoolState(pool)).shortSupply).to.eq(5);

    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(75000);

    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(10);

    expect((await getPoolState(pool)).longSupply).to.eq(15);
    expect((await getPoolState(pool)).shortSupply).to.eq(5);

    expect((await getPoolState(pool)).longRedeemPrice).to.eq(5);
    expect((await getPoolState(pool)).shortRedeemPrice).to.eq(15);
  });

  it('should correctly adjust the long redeem price', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);

    await pool.connect(coreContract.signer).init(50, Position.SHORT);
    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(5);
    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.position).to.eq(
      Position.LONG
    );

    await pool.connect(randomAddress).enter(50, Position.LONG);

    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(0);
    expect((await getPoolState(pool)).protocolState.size).to.eq(0);

    expect((await getPoolState(pool)).longSupply).to.eq(5);
    expect((await getPoolState(pool)).shortSupply).to.eq(5);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);

    await priceConsumer.connect(coreContract.signer).setPrice(15);
    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.cfdSize).to.eq(10);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(75000);

    expect((await getPoolState(pool)).longSupply).to.eq(5);
    expect((await getPoolState(pool)).shortSupply).to.eq(15);

    expect((await getPoolState(pool)).longRedeemPrice).to.eq(15);
    expect((await getPoolState(pool)).shortRedeemPrice).to.eq(5);
  });

  it('should correctly calculate the user balance in a 1-1 scenario (user against protocol)', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);

    expect(
      await pool.connect(pool.address).getUserBalance(Position.LONG)
    ).to.eq(50);

    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(75000);

    expect((await getPoolState(pool)).protocolState.size).to.eq(75000);

    expect((await getPoolState(pool)).shortRedeemPrice).to.eq(15);
    expect((await getPoolState(pool)).longRedeemPrice).to.eq(5);

    const userBalance = await pool
      .connect(pool.address)
      .getUserBalance(Position.LONG);

    expect(userBalance).to.equal(25);
  });

  it('should correctly calculate the user balance in a 1-2 scenario (user against protocol + user)', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);
    await pool.connect(randomAddress).enter(50, Position.LONG);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).protocolState.size).to.eq(0);

    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(75000);
    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);

    const userBalance = await pool
      .connect(await getAddressSigner(coreContract))
      .getUserBalance(Position.SHORT);

    expect(userBalance).to.equal(75);

    const randomAddressBalance = await pool
      .connect(randomAddress)
      .getUserBalance(Position.LONG);

    expect(randomAddressBalance).to.equal(25);
  });

  it('should correctly re-balance the pools after a price has changed, and new users enter pool', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.LONG);

    expect(await chipToken.balanceOf(pool.address)).to.equal(50);
    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);

    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(pool.signer).rebalance();

    expect((await getPoolState(pool)).shortPoolSize).to.eq(25000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(25000);

    await pool.connect(randomAddress).enter(50, Position.SHORT);

    expect((await getPoolState(pool)).protocolState.position).to.eq(
      Position.LONG
    );
    expect((await getPoolState(pool)).protocolState.size).to.eq(25000);

    expect((await getPoolState(pool)).shortPoolSize).to.eq(50000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(50000);
  });

  it('should stabilize the pools if a user deposits takes the position of the protocol, and deposits more than the exposure of the protocol', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);

    await pool.connect(coreContract.signer).init(50, Position.SHORT);
    await pool.connect(randomAddress).enter(80, Position.LONG);

    await pool.connect(pool.signer).rebalance();

    expect((await getPoolState(pool)).longPoolSize).to.eq(80000);
    expect((await getPoolState(pool)).shortPoolSize).to.eq(80000);
    expect((await getPoolState(pool)).protocolState.size).to.eq(30000);
    expect((await getPoolState(pool)).protocolState.position).to.eq(
      Position.SHORT
    );
  });

  it.skip('protocol should only burn the principal, and send the rest to the treasury', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.LONG);

    await chipToken.connect(pool.signer).approve(pool.address, 100);
    expect(await chipToken.balanceOf(pool.address)).to.equal(50);

    await priceConsumer.connect(coreContract.signer).setPrice(5);
    await pool.connect(pool.signer).rebalance();
    await pool.connect(randomAddress).enter(50, Position.SHORT);

    expect(await chipToken.balanceOf(treasury.address)).to.equal(24);
  });

  it('should take an 0.3% fee when entering an synthetic position', async () => {
    await deploy({
      fee: 0.03 * 1_000,
    });

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);
    await pool.connect(randomAddress).enter(50, Position.LONG);

    // It's a bit smaller than 0.03 % because of the precision that should be increased.
    expect((await getPoolState(pool)).shortPoolSize).to.eq(48000);
    expect((await getPoolState(pool)).longPoolSize).to.eq(48000);
  });

  it.skip('should correctly correctly mint $c on protocol rebalancing', async () => {
    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);
    await pool.connect(randomAddress).enter(50, Position.LONG);

    await priceConsumer.connect(coreContract.signer).setPrice(5);
    await pool.connect(coreContract.signer).rebalance();

    expect((await getPoolState(pool)).protocolState.size).to.eq(50000);
    expect(await chipToken.balanceOf(pool.address)).to.eq(50);
  });

  it.skip('should take an 0.3% fee on when exiting an synthetic position', () => {});

  it.skip('should correctly readjust the position of the protocol if a new user enters against the protocol', () => {});

  it.skip('should credit an disproportional amount of the less popular side when price moves in their favour', () => {});

  it.skip('should not be possible for users to frontrun oracle updates', () => {});

  it.skip('should correctly calculate how much a user can withdrawal', () => {});

  it.skip('should be possible to withdrawal directly', () => {});
});
