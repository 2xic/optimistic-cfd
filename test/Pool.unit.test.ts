import { expect } from "chai";
import { decodeBoolAbi } from "./helpers/decodeAbi";
import { deployContract } from "./helpers/deployContract";
import { getAddressSigner } from "./helpers/getAddressSigner";
import { sumChipQuantity } from "./helpers/sumPositions";

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

    const longCfdTokenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTokenBalance).to.equal(5);

    const shortCfdTokenBalance = await shortCfdTopken.balanceOf(
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

    const longCfdTokenBalance = await longCfdTOken.balanceOf(pool.address);
    expect(longCfdTokenBalance).to.equal(5);

    const shortCfdTokenBalance = await shortCfdTopken.balanceOf(
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

  it.skip("should keep the pools balanced after readjustment after a price decrease", () => {
    /**
     * One person enters trade
     * Protcol steps into other side of trade

    *  Price moves in faveour of other person. OK
     *  -> Protcol can just mints more on it's side
     * Price moves in ffavour of the the protcol
     *  -> Money should be moved from the other user and to the protcol
     *  -> then we need to mint on the side of the other person
    ->  

     But the protcol should only be on one side of the trade ? 
     
     norswap wrote : 
      Let's imagine the price goes up to 120$ and that short pool is 220 $C. 
      Then the balance will go to 200-200. Not 240-240! 
      
      **The protocol never chips in on both side, so because the short pool was reduced to 200 $C**
      
      , the protocol must remove 40 $C from the long side (which is now 220 + 20 profit). 
      If we ignore profit redistribution, this should 0.33333... $cfdETH == 40 $C at a price of 120 $C.
     */
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
