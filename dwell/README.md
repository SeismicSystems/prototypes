# Privacy-Preserving/Yield-Bearing Tokens

## Overview

**Problem**: Traditional rent payments are antiquated, requiring manual processing, offering no yield on deposits, and exposing sensitive financial information. This creates inefficiencies for both tenants and landlords while leaving value on the table.

**Insight**: Since rental markets operate on predictable payment schedules, there's an opportunity to optimize capital efficiency through automated payments and yield generation. Privacy-preserving mechanisms can protect sensitive financial data while maintaining transparency where needed.

**Solution**: USDY (USD Yield) implements a privacy-preserving token system for rental payments that generates yield during deposit periods while protecting transaction privacy. Tenants can earn returns on their deposits until rent is due, landlords receive guaranteed on-time payments, and all parties maintain financial privacy through shielded transactions. The system uses a shares-based accounting mechanism to distribute yield fairly among all participants.

## Architecture

- `SRC20.sol`: Base privacy-preserving ERC20 implementation using shielded types
- `ISRC20.sol`: Interface for shielded ERC20 functionality
- `USDY.sol`: Yield-bearing USD stablecoin with privacy features
- Comprehensive test suite in `test/` directory

## License

AGPL-3.0-only
