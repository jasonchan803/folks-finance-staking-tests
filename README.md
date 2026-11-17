# Folks Finance Staking - Foundry Security Tests

## Project Overview

This repository contains my independent Foundry testing practice based on the Folks Finance Staking smart contract codebase.

The original protocol implementation belongs to Folks Finance. I modified and extended the test suite to investigate specific contract behaviors and security scenarios.

## Branches

This repository contains two branches for historical vulnerability reproduction and fix verification.

### `main` - Fix Verification

Uses the updated Folks Finance Staking implementation.

The tests verify:

- Permit signature validation
- Expired permit handling
- Small withdrawal and reward rounding behavior
- Migration permit revocation after the migrator role is revoked
- Prevention of migration after the permit has been revoked

### `historical-vulnerability` - Historical Vulnerability Reproduction

Contains the historical vulnerability reproduction based on the pre-fix contract logic.

This branch preserves the original test scenario to demonstrate the behavior before the fix.

## Test Coverage

1. Permit signature validation
2. Expired permit handling
3. Small withdrawal and reward rounding behavior
4. Migration permit behavior after migrator role revocation

## Test Results

The updated implementation was tested locally using Foundry.

- Total tests: 4
- Passed: 4
- Failed: 0

GitHub Actions is configured to run the Foundry tests automatically on repository updates.

## Testing Environment

- Solidity
- Foundry
- Forge
- GitHub Actions

## Running Tests

Run all tests:

```bash
forge test -vvv
```

Run the custom test file:

```bash
forge test --match-path test/Mytest.t.sol -vvv
```

## License and Attribution

The original Folks Finance Staking smart contract code is licensed under the Business Source License 1.1 (BSL 1.1).

Original repository:

https://github.com/Folks-Finance/folks-staking-contracts

The original protocol implementation and related intellectual property belong to FOLKS FINANCE PRIVATE FOUNDATION.

Please refer to `LICENSE.md` for the applicable license terms.

## Disclaimer

This is an independent security testing and learning project. It is not an official security audit or an official contribution to Folks Finance.

The historical vulnerability reproduction is intended for educational and security research purposes.
