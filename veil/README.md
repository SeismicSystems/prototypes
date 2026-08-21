# VEIL: Win a raffle no one can rig, and no one can trace back to you

## Overview

**Problem**: A public raffle leaks its own odds while it is still running. Anyone can watch the pool grow, time their entry against the visible total, or wait to see how many tickets are already in play before deciding whether to join. Randomness sourced from ordinary chain data fares no better: whoever proposes or times a block has some influence over it, and once a contract's "random" output becomes a public value, anyone who can read it before deciding whether to keep or discard a transaction can grind for a favorable outcome instead of accepting the one they were dealt.

**Insight**: Two things have to be true at once for a raffle to be trustworthy: the draw has to be unbiasable by anyone including the party who triggers it, and the outcome has to be unobservable to anyone until they have committed to living with it. Seismic's native randomness gives the first property. Shielded storage, used correctly, gives the second, and it turns out the second property is also what makes an anonymous winner possible: if no one, including the winner's own wrapper contract, can read the outcome before it is final, then no one can act on it early, and no one but the winner themselves can ever connect an address to the result.

**Solution**: Entrants buy tickets by pulling payment through a shielded SRC20 token, so the amount they pay for never appears as a public transaction field. Each entrant's stake is recorded as a range carved out of a running total that stays encrypted until the draw. At the draw, Seismic's RNG builtin picks a winning ticket number, but that number is never declassified. It stays shielded in contract storage permanently. The only way for anyone to learn anything about the outcome is to call `claim`, which reveals nothing beyond whether the caller's own private range happens to cover the hidden ticket.

## How the draw resists grinding

A naive version of this design has two holes, and closing both is the actual point of the contract, not an afterthought.

The first hole is an off-chain self-oracle: if the winning ticket number is ever made public, an entrant who knows their own range boundaries, most obviously the entrant holding ticket 0 or the entrant holding the last ticket, can wrap `draw` in their own contract, read the now-public result, and revert the whole transaction if it does not favor them. Veil closes this by never declassifying the winning ticket. It is computed and stored as a shielded value from the moment Seismic's randomness builtin returns it, and there is no getter, no event field, and no other state variable anywhere in the contract that exposes it. There is nothing for a wrapper to read.

The second hole is atomic bundling: even with a hidden result, a contract that lets the same transaction both trigger the draw and check whether it won can simply revert the whole thing when it loses, and try again in a fresh transaction. Veil closes this by recording the block the draw ran in and requiring `claim` to run in a strictly later block. Within a single transaction the block number cannot advance, so `claim` can never succeed in the same transaction as `draw`, no matter how the call is structured. The draw commits irrevocably in its own transaction, before anyone, including whoever triggered it, has any way to know what it will show.

## Architecture

- `Veil.sol`: the raffle itself, entries, the draw, and claims
- `ISRC20.sol`: interface for the shielded token entrants pay with
- Test suite in `test/`, including a mock SRC20 token and reproductions of both grinding attacks described above, proving each one fails against the current design

## Limitations

**The draw is not independently auditable after the fact.** Because the winning ticket is never declassified, nobody outside the contract, not even after the raffle has concluded, can recompute which ticket number should have won and check it against who actually claimed. All anyone can verify is that a specific claimed payout occurred. This is the direct and deliberate cost of the anonymity property this design is built around, not an oversight. A raffle that needs to be publicly auditable end to end would need a different design, one that accepts a public draw and gives up winner anonymity in exchange.

**The raffle depends on someone calling `draw` after the deadline.** Nothing in the contract incentivizes this beyond entrants wanting their prize. If no one calls it, the raffle simply never draws.

**Two small, accepted signals remain.** Attempting to enter with zero tickets reveals a zero-versus-nonzero fact about that one attempt before it reverts, the same pattern used throughout this design's ticket bookkeeping. And a losing `claim` call reveals, to the caller alone, that they did not win. Neither leaks anything about any other entrant, the pool total before the draw, or the raw winning ticket value, and neither can be used to influence the outcome; they are the minimum information a participant is owed about their own result.

**Count privacy only means something with a healthy number of entrants.** Every address that enters is public through the `Entered` event, and `draw` declassifies the total ticket count. With one entrant, the total ticket count and that entrant's own ticket count are the same number: their stake is fully exposed and they are also guaranteed to win, so shielding buys them nothing. With two entrants, each one knows their own count and can subtract it from the declassified total to learn the other's count exactly. The privacy this design provides over ticket counts is a property of the crowd, not of the mechanism in isolation, and it only becomes meaningful once enough entrants have joined that the total no longer narrows down any single participant's stake. This is not a flaw to be fixed later; it is a real limit on what shielding a running total can do, and it should be stated plainly rather than implied away.

## License

MIT
