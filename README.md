# Folks Finance Staking - Foundry Security Tests

## Project Overview

This repository contains my independent Foundry testing practice based on the Folks Finance Staking smart contract codebase.

The original protocol implementation belongs to Folks Finance. I modified and extended the test suite to investigate specific contract behaviors and security scenarios.

## Test Coverage

1. Permit signature validation
2. Expired permit handling
3. Small withdrawal and reward rounding behavior
4. Migration permission behavior after migrator role revocation

## Test Results

- Total tests: 4
- Passed: 4
- Failed: 0

## Testing Environment

- Solidity
- Foundry
- Forge

## License and Attribution

The original Folks Finance Staking smart contract code is licensed under the Business Source License 1.1 (BSL 1.1).

Original repository:  
https://github.com/Folks-Finance/folks-staking-contracts

The original protocol implementation and related intellectual property belong to FOLKS FINANCE PRIVATE FOUNDATION.

This repository contains independent testing work based on the original codebase. The original license terms remain applicable to the original and modified project code. Please refer to `LICENSE.md` for the full license terms.

## Disclaimer

This is an independent security testing and learning project. It is not an official security audit or an official contribution to Folks Finance.
