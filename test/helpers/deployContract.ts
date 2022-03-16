import { ethers } from "hardhat";

export async function deployContract() {
  // eslint-disable-next-line no-unused-vars
  const [_owner, randomAddress] = await ethers.getSigners();

  const PositionHelper = await ethers.getContractFactory("PositionHelper");
  const positionHelper = await PositionHelper.deploy();

  const CoreContract = await ethers.getContractFactory("CoreContract");
  const coreContract = await CoreContract.deploy();
  await coreContract.deployed();

  const ChipTokenContract = await ethers.getContractFactory("Chip");
  const chipToken = await ChipTokenContract.deploy(
    await coreContract.signer.getAddress()
  );

  const LongCfdEthContract = await ethers.getContractFactory("EthLongCfd");
  const longCfdTOken = await LongCfdEthContract.deploy(_owner.address);
  await longCfdTOken.deployed();

  const ShortCfdEthContract = await ethers.getContractFactory("EthShortCfd");
  const shortCfdToken = await ShortCfdEthContract.deploy(_owner.address);
  await shortCfdToken.deployed();

  const PriceConsumerV3Contract = await ethers.getContractFactory(
    "MockPriceOracle"
  );
  const priceConsumer = await PriceConsumerV3Contract.deploy();
  await priceConsumer.deployed();

  const PoolContract = await ethers.getContractFactory("Pool", {
    libraries: {
      PositionHelper: positionHelper.address,
    },
  });
  const pool = await PoolContract.deploy(
    priceConsumer.address,
    chipToken.address,
    longCfdTOken.address,
    shortCfdToken.address
  );
  await pool.deployed();

  await longCfdTOken.transferOwnerShip(pool.address);
  await shortCfdToken.transferOwnerShip(pool.address);

  return {
    ChipTokenContract,
    CoreContract,
    chipToken,
    coreContract,
    randomAddress,
    longCfdTOken,
    shortCfdToken,
    PoolContract,
    pool,
    priceConsumer,
  };
}
