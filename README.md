# punk-nftx-meebit-arb

1. Flash loan ETH
2. Swap for [NFTX](https://github.com/NFTX-project/x-contracts) PUNK-BASIC on SushiSwap
3. Redeem PUNK-BASIC for punk, claim [Meebit](https://meebits.larvalabs.com/) for punks that have available redemption (revert on failure), return punk to NFTX
4. Random punk returned each claim. Repeat to claim a Meebit for each availble fund punk.
5. Sell PUNK-BASIC on @SushiSwap, return ETH

**Exit liquidity:** immediate sale at Meebit price floor, NFTX tokenization, chance for better outcome.

**Alternative:** Optimize by using a [Flash Swap](https://uniswap.org/docs/v2/core-concepts/flash-swaps/) to remove entire PUNK-BASIC resrrve in (1/2)
