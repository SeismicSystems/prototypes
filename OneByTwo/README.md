# OneByTwo - Restaurant Revenue Sharing

### Overview

OneByTwo allows restaurants to mint tokens that entitle frequent customers to a portion of their revenue.

**Problem:** Traditional token implementations expose balances and addresses to all observers on a given chain. This gets in the way of
consumer applications that require a degree of privacy, such as benefits models that need to track both spend and user identities. For restaurants paticularly,
protecting the privacy of frequent clients is critical as they drive a large portion of the restaurant's revenue streams and often have long-standing relationships with
the businesses that they frequent.

**Insight:** Shielded types, as implemented by Seismic, allows contracts to hide transaction amounts and addresses when broadcasting events. As this applies to restaurants, it gives benefits models the ability to log events on-chain while preserving user privacy.

**Solution:** OneByTwo leverages s-types and the relationship between restaurants and their top customers to build out a rewards platform that entitles said customers to a portion of the restaurants revenue stream. This is done with tokens: restaurants mint tokens that represent their revenue stream. Restaurants then distribute those tokens amongst customers as they see fit. From there, custoemrs can trade their tokens for an equivalent portion of the restaurants revenue. Customers have the ability to cash out their tokens whenever, and the smart contract will handle the return of the tokens and the distribution of revenue.
