import { expect } from "chai";
import { decodeBoolAbi } from "./helpers/decodeAbi";
import { deployContract } from "./helpers/deployContract";
import { getAddressSigner } from "./helpers/getAddressSigner";
import { sumChipQuantity } from "./helpers/sumPositions";
import { Position } from "./types/Position";
import forEach from "mocha-each";

describe("Pool", () => {
  it("should move $c from the short pool to the long pool on price increase", async () => {
    const {
      chipToken,
      coreContract,
      pool,
      longCfdTOken,
      shortCfdToken,
      priceConsumer,
    } = await deployContract();
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

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    const longCfdTokenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTokenBalance).to.equal(5);

    const shortCfdTokenBalance = await shortCfdToken.balanceOf(
      coreContractSignerAddress
    );
    expect(shortCfdTokenBalance).to.equal(5);

    expect(sumChipQuantity(await pool.getShorts())).to.equal(50000);
    expect(sumChipQuantity(await pool.getLongs())).to.equal(50000);

    // 50% price increase
    await priceConsumer.connect(coreContract.signer).setPrice(15);

    await pool.connect(coreContract.signer).rebalancePools();

    expect(sumChipQuantity(await pool.getShorts())).to.equal(25000);
    expect(sumChipQuantity(await pool.getLongs())).to.equal(75000);
  });

  it("should move $c from the long pool to the short pool on price decrease", async () => {
    const {
      chipToken,
      coreContract,
      pool,
      longCfdTOken,
      shortCfdToken,
      priceConsumer,
    } = await deployContract();
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

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    const longCfdTokenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTokenBalance).to.equal(5);

    const shortCfdTokenBalance = await shortCfdToken.balanceOf(
      coreContractSignerAddress
    );
    expect(shortCfdTokenBalance).to.equal(5);

    expect(sumChipQuantity(await pool.getShorts())).to.equal(50000);
    expect(sumChipQuantity(await pool.getLongs())).to.equal(50000);

    // 50% price decrease
    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).rebalancePools();

    expect(sumChipQuantity(await pool.getLongs())).to.equal(25000);
    expect(sumChipQuantity(await pool.getShorts())).to.equal(75000);
  });

  it("should not be possible to call the init function multiple times", async () => {
    const { chipToken, coreContract, pool, priceConsumer } =
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

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.SHORT);

    await expect(
      pool.connect(coreContract.signer).init(50, Position.SHORT)
    ).to.be.revertedWith("Init should only be called once");
  });

  forEach([[Position.SHORT], [Position.LONG]]).it(
    "should correctly adjust the pools after a price move against the protocol position",
    async (userPosition) => {
      const { chipToken, coreContract, pool, priceConsumer } =
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

      await priceConsumer.connect(coreContract.signer).setPrice(10);
      await pool.connect(coreContract.signer).init(50, userPosition);

      const updatedCoreContractBalance = await chipToken.balanceOf(
        coreContractSignerAddress
      );
      expect(updatedCoreContractBalance).to.equal(50);

      expect(sumChipQuantity(await pool.getShorts())).to.equal(50000);
      expect(sumChipQuantity(await pool.getLongs())).to.equal(50000);

      if (userPosition === Position.SHORT) {
        await priceConsumer.connect(coreContract.signer).setPrice(5);
      } else {
        await priceConsumer.connect(coreContract.signer).setPrice(15);
      }

      await pool.connect(coreContract.signer).update();

      expect(sumChipQuantity(await pool.getLongs())).to.equal(75000);
      expect(sumChipQuantity(await pool.getShorts())).to.equal(75000);
    }
  );

  it("should keep the pools balanced after priced move with the protocol", async () => {
    const userPosition = Position.LONG;
    const { chipToken, coreContract, pool, priceConsumer } =
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

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, userPosition);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    expect(sumChipQuantity(await pool.getShorts())).to.equal(50000);
    expect(sumChipQuantity(await pool.getLongs())).to.equal(50000);

    // Protcol will be short, and will therefore "burn" the outstanding

    await priceConsumer.connect(coreContract.signer).setPrice(5);

    await pool.connect(coreContract.signer).update();

    expect(sumChipQuantity(await pool.getLongs())).to.equal(25000);
    expect(sumChipQuantity(await pool.getShorts())).to.equal(25000);
  });

  it("should burn minted $c if fresh users join the pool", async () => {
    const { chipToken, randomAddress, coreContract, pool, priceConsumer } =
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

    await priceConsumer.connect(coreContract.signer).setPrice(10);
    await pool.connect(coreContract.signer).init(50, Position.LONG);
    await pool.connect(randomAddress).enter(50, Position.SHORT);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    expect(sumChipQuantity(await pool.getShorts())).to.equal(50000);
    expect(sumChipQuantity(await pool.getLongs())).to.equal(50000);

    expect((await pool.getShorts()).length).to.equal(1);
    expect((await pool.getLongs()).length).to.equal(1);
  });

  it.skip("protocol should only burn the principal, and send the rest to the treasury", () => {
    expect.fail("not implemented");
  });

  it.skip("should stabilize the pools if a user deposits takes the position of the protocol, and deposits more than the exposure of the protocol", () => {
    // i.e protocol is long with 50 $c, and a user goes long with 75$, then the protocol has to go short with 25$
    expect.fail("not implemented");
  });

  it.skip("should correctly readjust the position of the protocol if a new user enters against the protocol", () => {
    expect.fail("not implemented");
  });

  it.skip("should update the ownership users has of the long pool on price increase", () => {
    expect.fail("not implemented");
  });

  it.skip("should update the ownership users has of the short pool on price increase", () => {
    expect.fail("not implemented");
  });

  it.skip("should update the ownership users has of the short pool on price decrease", () => {
    expect.fail("not implemented");
  });

  it.skip("should update the ownership users has of the long pool on price decrease", () => {
    expect.fail("not implemented");
  });

  it.skip("should credit an disproportional amount of the less popular side when price moves in their favour", () => {
    expect.fail("not implemented");
  });

  it.skip("should not be possible for users to frontrun oracle updates", () => {
    expect.fail("not implemented");
  });
});
