# Optimistic CFD
Smart contracting functionality for matching "users" that want to go long on a asset (ETH/ERC20) with someone who want's to go short. CFD like.

## CFD 
Allows users to speculate on a asset without ownership of an given asset. Payout is difference between the opening price of the contract, and the price of the expiry date.

## Approach (MVP)
User create an order, or can take the opposite side of an existing order. 
An order consist of the expiry date for contract and the order, contract "value" (i.e the collateral, and max amount to loose), if the position is long or short, and asset (ETH/ERC20).

Order matching is done inside the contract, and not offchain. In the MVP version all orders are 1:1, but in the future support for difference ratio based on market conditions would make sense (if the entire market is crashing going long should yield higher payout than going short).

Both user has to deposit the value of the contract as collateral. To make things a bit simpler, I think we value all contracts in ETH, and when the contract expire we do payout based on changes in the underlying asset against ETH. We will use ChainLink for price history [1].
Users can also never loose more than what they put up as collateral.

[1] https://docs.chain.link/docs/historical-price-data/

