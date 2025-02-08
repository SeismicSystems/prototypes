# Privacy-Preserving/Yield-Bearing Tokens

## Overview

**Problem**: Traditional ERC20 tokens expose all balances and transfers publicly on-chain, compromising user privacy. Additionally, yield-bearing tokens often require complex rebasing mechanisms that can lead to accounting errors and UX issues.

**Insight**: By using shielded types (e.g. `saddress`, `suint256`) for balances and transfers while maintaining public total supply, we can achieve meaningful privacy without sacrificing key token functionality. A shares-based accounting system can elegantly handle yield accrual without rebasing.

**Solution**: USDY (USD Yield) implements a privacy-preserving ERC20 token that uses shielded balances and transfers while accruing yield through an internal shares-based accounting system. The token maintains standard ERC20 compatibility and allows only account owners to view their true balances, while other accounts see zero balances. Yield is distributed proportionally to all token holders through a reward multiplier mechanism that adjusts the share-to-token ratio.

## Architecture

- `SRC20.sol`: Base privacy-preserving ERC20 implementation using shielded types
- `ISRC20.sol`: Interface for shielded ERC20 functionality
- `USDY.sol`: Yield-bearing USD stablecoin with privacy features
- Comprehensive test suite in `test/` directory
- Deployment scripts in `script/` directory

## License

AGPL-3.0-only
