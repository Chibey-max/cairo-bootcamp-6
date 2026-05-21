# Transfer Agent

`transfer-agent` is a TypeScript workflow that automates a Starknet transfer decision using the `starknet-agentic` MCP server. It was built for **Test 2: Automated Transfer & Multi-Step Agent Workflow**.

The agent does not blindly send funds. It first checks the wallet balance, validates a configurable rule, runs the transfer in dry-run or execute mode, performs a second MCP-powered action, writes a JSONL receipt, and alerts when the account balance is low.

## Workflow Summary

| Step | Requirement | Implementation | MCP Tool |
| --- | --- | --- | --- |
| 1 | Fetch wallet balance | `steps/balance.ts` | `starknet_get_balance` |
| 2 | Validate transfer condition | `steps/validate.ts` checks `balance > MIN_BALANCE_TO_TRANSFER` | Local validation |
| 3 | Transfer if allowed | `steps/transfer.ts` simulates or submits transfer | `starknet_transfer` |
| 4 | Run another action/function | `steps/post-action.ts` | `starknet_get_balances` or `starknet_call_contract` |
| 5 | Log execution result | `src/log.ts` appends one JSON object per run | Local logging |
| 6 | Alert on low balance | `steps/validate.ts` checks `balance < ALERT_BALANCE_THRESHOLD` | Local alert |

See [`workflows/transfer.md`](./workflows/transfer.md) for the step-by-step workflow map.

## Project Structure

```text
transfer-agent/
  package.json              # Scripts and dependencies
  tsconfig.json             # TypeScript configuration
  .env.example              # Environment template
  config.ts                 # Environment parsing and validation
  run.ts                    # Main workflow orchestrator
  workflows/
    transfer.md             # Human-readable workflow map
  steps/
    balance.ts              # Step 1: read account balance
    validate.ts             # Steps 2 and 6: decision and alert rules
    transfer.ts             # Step 3: transfer simulation/execution
    post-action.ts          # Step 4: second MCP action
  src/
    mcp.ts                  # MCP sidecar client
    log.ts                  # Structured console + JSONL logging
    notify.ts               # Terminal notification formatting
    types.ts                # Shared workflow types
```

## Requirements

| Requirement | Purpose |
| --- | --- |
| Node.js | Runs the TypeScript agent. |
| npm | Installs local dependencies. |
| `starknet-agentic` | Provides the MCP server used by the agent. |
| Starknet Sepolia account | Used to check balances and optionally submit transfers. |
| Starknet RPC URL | Network endpoint used by the MCP server. |

## Setup

First build the MCP server from the sibling `starknet-agentic` project:

```bash
cd ../starknet-agentic
pnpm install
pnpm build
```

Then configure the transfer agent:

```bash
cd ../transfer-agent
cp .env.example .env
npm install
```

Edit `.env` and fill in:

```text
STARKNET_RPC_URL
STARKNET_ACCOUNT_ADDRESS
STARKNET_PRIVATE_KEY
TRANSFER_RECIPIENT
```

Keep `.env` private. It can contain funded account credentials.

## Configuration

| Variable | Required | Description |
| --- | --- | --- |
| `STARKNET_RPC_URL` | Yes | Starknet RPC endpoint, usually Sepolia for testing. |
| `STARKNET_ACCOUNT_ADDRESS` | Yes | Sender account address. |
| `STARKNET_PRIVATE_KEY` | Yes | Sender private key used by the MCP server. |
| `TRANSFER_MCP_ENTRY` | No | Path to the built `starknet-agentic` MCP server entry file. |
| `TRANSFER_TOKEN` | No | Token symbol to transfer. Defaults to `STRK`. |
| `TRANSFER_RECIPIENT` | Yes | Recipient address for the transfer step. |
| `TRANSFER_AMOUNT` | No | Amount to transfer when the rule passes. Defaults to `0.1`. |
| `MIN_BALANCE_TO_TRANSFER` | No | Transfer only when balance is strictly greater than this value. |
| `ALERT_BALANCE_THRESHOLD` | No | Print a warning when balance is below this value. |
| `TRANSFER_EXECUTE` | No | `0` simulates only, `1` submits a real transaction. |
| `POST_ACTION` | No | `get_balances`, `call_contract`, or `none`. |
| `TOKEN_CONTRACT_ADDRESS` | Sometimes | Required when `POST_ACTION=call_contract`. |
| `TRANSFER_LOG_FILE` | No | JSONL receipt output path. Defaults to `./transfer-agent-log.jsonl`. |

## Run

Run all workflow steps in dry-run mode:

```bash
npm run run:dry
```

Run all workflow steps and submit a real transfer when the rule passes:

```bash
npm run run:execute
```

The `send` script is an alias for execute mode:

```bash
npm run send
```

You can also override values for a single run:

```bash
TRANSFER_RECIPIENT=0x123 \
TRANSFER_AMOUNT=1 \
TRANSFER_EXECUTE=0 \
npm run run
```

## Dry-Run vs Execute Mode

| Mode | Value | Behavior |
| --- | --- | --- |
| Dry-run | `TRANSFER_EXECUTE=0` | Runs the workflow and simulates the transfer without sending funds. |
| Execute | `TRANSFER_EXECUTE=1` | Sends a real Starknet transaction if the balance rule passes. |

Start with dry-run mode until the account, recipient, amount, and threshold values are confirmed.

## Terminal Notifications

The agent prints boxed terminal notifications for important events:

| Notification | Meaning |
| --- | --- |
| Simulated | Transfer step ran without submitting a transaction. |
| Submitted | A real transaction was submitted. |
| Confirmed | Transaction confirmation was detected. |
| Failed | A step failed or the transaction failed. |
| Skipped | Balance rule blocked the transfer. |
| Balance alert | Balance is below the configured alert threshold. |

Optional notification controls:

```text
TERMINAL_NOTIFY=0
TERMINAL_BELL=0
```

## Logs and Evidence

Each run appends one JSON object to:

```text
transfer-agent-log.jsonl
```

The receipt includes:

| Field | Description |
| --- | --- |
| `timestamp` | Time the workflow completed. |
| `token` | Token symbol used for the balance/transfer step. |
| `balanceBefore` | Balance read before the transfer decision. |
| `alert` | Low-balance alert result. |
| `decision` | Whether the agent chose to transfer or skip. |
| `transfer` | Transfer simulation/submission result. |
| `postAction` | Result of the second MCP action. |

For bootcamp evidence, include console output and selected JSONL entries, but do not commit the log file if it contains private run details.

## Safety Notes

- Keep `.env` out of Git.
- Use Sepolia while testing.
- Run `npm run run:dry` before enabling execute mode.
- Double-check `TRANSFER_RECIPIENT` before setting `TRANSFER_EXECUTE=1`.
- Do not commit `node_modules/` or `transfer-agent-log.jsonl`.
