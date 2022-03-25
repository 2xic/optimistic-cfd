/*
Todo : 
Write tests for the withdrawal logic.

Norswap wrote the following regarding this (https://github.com/2xic/optimistic-cfd/issues/1):

Alternatively, and this is probably a better approach, we could avoid minting $CFD, and just offering a discount on a $C-$CFD AMM purchase. This would have the stabilizing benefit that if the exit queue gets too full, demand for $CFD will be stimulated. It goes without saying that this all requires more thinking / modelling.

This means that $CFD will go down in value when the TVL decreases. However, $CFD holders benefit when the TVL increases: when the queue is empty, the protocol mints $C in exchanged for other stablecoins, and those go straight to the protocol's treasury. And the treasury essentially provides a floor on the $CFD price.

*/

describe('WithdrawalQueue', () => {});
