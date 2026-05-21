# Restricted ERC20 Token

`erc_token` is a Cairo smart contract project that implements an ERC20-style token with additional owner-controlled restrictions. The contract is named `RestrictedToken` and is designed for Starknet using Scarb and Starknet Foundry.

## Overview

The token supports the common ERC20 actions:

| Feature | Description |
| --- | --- |
| Metadata | Stores token name, symbol, decimals, and total supply. |
| Balances | Tracks balances for Starknet contract addresses. |
| Transfers | Allows token holders to transfer tokens to another address. |
| Allowances | Supports `approve`, `transfer_from`, `increase_allowance`, and `decrease_allowance`. |
| Events | Emits `Transfer` and `Approval` events for ERC20-style actions. |

It also includes restricted-token behavior:

| Feature | Description |
| --- | --- |
| Owner | The constructor stores an owner address. |
| Transfer limit | Transfers cannot exceed the configured `transfer_limit`. |
| Limit updates | Only the owner can update the transfer limit. |
| Admin burn | Only the owner can burn tokens from an account. |
| Revoke | A token holder can revoke an existing spender allowance. |

## Token Details

The current constructor initializes the token with:

| Field | Value |
| --- | --- |
| Name | `Dave` |
| Symbol | `DAVE` |
| Decimals | `18` |
| Default transfer limit | `10,000` |

The constructor accepts:

```text
owner: ContractAddress
initial_supply: u256
recipient: ContractAddress
```

If `initial_supply` is greater than zero, the supply is minted to `recipient`.

## Project Structure

```text
erc_token/
  Scarb.toml                    # Package manifest and dependencies
  snfoundry.toml                # Starknet Foundry configuration
  src/
    lib.cairo                   # RestrictedToken contract implementation
    interfaces.cairo            # ERC20 and restricted token interfaces
    errors.cairo                # Shared assertion error constants
  tests/
    test_restricted_token.cairo # Contract behavior tests
  scripts/
    deploy_sepolia.sh           # Sepolia declare/deploy/call/invoke helper
```

## Requirements

Install the Cairo/Starknet toolchain before running the project:

| Tool | Purpose |
| --- | --- |
| Scarb | Builds and manages Cairo packages. |
| Starknet Foundry | Runs tests and provides `snforge`/`sncast`. |

The project uses:

```toml
starknet = "2.18.0"
openzeppelin_access = "3.0.0"
openzeppelin_token = "3.0.0"
snforge_std = "^0.60.0"
```

## Setup

From the project folder:

```bash
cd erc_token
scarb build
```

## Run Tests

Run the full test suite:

```bash
scarb test
```

The tests cover:

| Test Area | What is checked |
| --- | --- |
| Constructor | Metadata, initial supply, recipient balance, and default transfer limit. |
| Transfers | Balance movement between sender and recipient. |
| Allowances | Approval and `transfer_from` allowance spending. |
| Owner controls | Owner-only transfer limit updates. |
| Transfer limit | Transfers over the configured limit fail. |
| Revoke | Revoking empty and existing allowances. |
| Admin burn | Owner burn reduces both balance and total supply. |
| Access control | Non-owner calls to owner-only functions fail. |

## Contract Interface

### ERC20 Functions

```text
get_name() -> felt252
get_symbol() -> felt252
get_decimals() -> u8
get_total_supply() -> u256
balance_of(account) -> u256
allowance(owner, spender) -> u256
transfer(recipient, amount)
transfer_from(sender, recipient, amount)
approve(spender, amount)
increase_allowance(spender, added_value)
decrease_allowance(spender, subtracted_value)
```

### Restricted Token Functions

```text
get_transfer_limit() -> u256
set_transfer_limit(new_limit)
admin_burn(account, amount)
revoke(spender) -> bool
```

## Important Rules

The contract rejects unsafe actions with assertion errors:

| Error | Meaning |
| --- | --- |
| `ONLY_OWNER` | Caller is not the stored owner. |
| `INVALID_LIMIT` | New transfer limit cannot be zero. |
| `TRANSFER_LIMIT_EXCEEDED` | Transfer amount is above the configured limit. |
| `ZERO_OWNER` | Constructor owner cannot be zero. |
| `ZERO_RECIPIENT` | Constructor recipient cannot be zero. |
| `ZERO_ACCOUNT` | Account argument cannot be zero. |
| `ZERO_SPENDER` | Spender argument cannot be zero. |
| `ZERO_AMOUNT` | Amount argument cannot be zero. |
| `ERC20_INSUFFICIENT_BALANCE` | Account does not have enough tokens. |
| `ERC20_INSUFFICIENT_ALLOWANCE` | Spender allowance is too low. |

## Sepolia Deployment

The helper script can build, declare, deploy, call read functions, and run sample invokes on Sepolia:

```bash
cd erc_token
./scripts/deploy_sepolia.sh
```

Individual steps are also available:

```bash
./scripts/deploy_sepolia.sh declare
./scripts/deploy_sepolia.sh deploy
./scripts/deploy_sepolia.sh call
./scripts/deploy_sepolia.sh invoke
```

The script uses the `sepolia` profile from `snfoundry.toml` and expects a configured Starknet account. After deployment, it stores the deployed contract address in:

```text
scripts/.deployed_address
```

## Notes for PR Submission

When submitting this folder, include source, tests, Scarb files, and the deployment script. Do not include generated build/cache artifacts:

```text
target/
.snfoundry_cache/
scripts/.deployed_address
scripts/.class_hash
```
