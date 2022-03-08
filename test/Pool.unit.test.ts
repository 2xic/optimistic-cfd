import { expect } from "chai";
import { decodeBoolAbi } from "./helpers/decodeAbi";
import { deployContract } from "./helpers/deployContract";
import { getAddressSigner } from "./helpers/getAddressSigner";

describe("Pool", () => {
  it("should move $c from the short pool to the long pool on price increase", async () => {
    const {
      chipToken,
      coreContract,
      pool,
      longCfdTOken,
      shortCfdTopken,
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
    await pool.connect(coreContract.signer).init(50, 1);

    const updatedCoreContractBalance = await chipToken.balanceOf(
      coreContractSignerAddress
    );
    expect(updatedCoreContractBalance).to.equal(50);

    const longCfdTOkenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTOkenBalance).to.equal(5);

    const shortCfdTokenBalance = await shortCfdTopken.balanceOf(
      coreContractSignerAddress
    );
    expect(shortCfdTokenBalance).to.equal(5);

    expect((await pool.longPositions(0)).chipQuantity).to.equal(50000);
    expect((await pool.shortPositons(0)).chipQuantity).to.equal(50000);

    // 50% price increase
    await priceConsumer.connect(coreContract.signer).setPrice(15);

    await pool.connect(coreContract.signer).rebalancePools();

    expect((await pool.shortPositons(0)).chipQuantity).to.equal(25000);
    expect((await pool.longPositions(0)).chipQuantity).to.equal(75000);
  });

  it.skip("should move $c from the long pool to the short pool on price decrease", () => {
    expect.fail("not implemented");
  });

  it.skip("should keep the pools balanced after readjustment after a price decrease", () => {
    expect.fail("not implemented");
  });

  it.skip("should keep the pools balanced after readjustment after a price increase", () => {
    expect.fail("not implemented");
  });

  it.skip("should burn minted $c if fresh users join the pool", () => {
    expect.fail("not implemented");
  });

  it.skip("protcol should only burn the principal, and send the rest to the treasury", () => {
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

  it.skip("should credit an dispropotional amount of the less popular side when price moves in their favouir", () => {
    expect.fail("not implemented");
  });
});
