# Optimistic CFD
Smart contract for matching "users" that want to go long on a asset (ETH/ERC20) with someone who want's to go short. CFD like.

## CFD 
Allows users to speculate on a asset without ownership of an given asset. Profit/loss is the difference between the opening price at the start date of the contract, and the price at the expiry date. 
You earn if the price is increasing and you are long, and loose if you are long and price goes down (and the other way for going short).

## Approach (MVP)
Users can create an order, or can take the opposite side of an existing order. 
An order consist of the expiry date for contract and the order, contract "value" (i.e the collateral, and max amount to loose), if the position is long or short, and asset (ETH/ERC20).

Order matching is done inside the contract. For the MVP version all orders are 1:1, but in the future support for difference ratio based on market conditions would make sense (if the entire market is crashing going long should yield higher payout than going short).

Both user has to deposit the value of the contract as collateral. To make things a bit simpler, I think it makes sense to value all contracts in ETH. At the expiration of the payout is done based on changes in the underlying asset against ETH. We will use ChainLink for price history [1].
Users can also never loose more than what they put up as collateral.

[1] https://docs.chain.link/docs/historical-price-data/
