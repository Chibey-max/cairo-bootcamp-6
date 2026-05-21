# Transfer Agent Workflow

Composable multi-step workflow using **starknet-agentic** MCP tools (`packages/starknet-mcp-server`).

## Steps

| # | Requirement | Module | Action |
|---|-------------|--------|--------|
| 1 | Fetch wallet balance | `steps/balance.ts` | `starknet_get_balance` |
| 2 | Validate transfer condition | `steps/validate.ts` | `balance > MIN_BALANCE_TO_TRANSFER` |
| 3 | Transfer if condition passes | `steps/transfer.ts` | `starknet_transfer` (dry-run, then execute if `TRANSFER_EXECUTE=1`) |
| 4 | Call another function/agent | `steps/post-action.ts` | `starknet_get_balances` or `starknet_call_contract` |
| 5 | Log execution result | `src/log.ts` | Append JSON to `transfer-agent-log.jsonl` |
| 6 | Alert on low balance | `steps/validate.ts` | `WARN` if `balance < ALERT_BALANCE_THRESHOLD` |

## Run

```bash
cd transfer-agent
npm run run:dry      # steps 1–6, simulated transfer
npm run run:execute  # steps 1–6, real transfer when allowed
```

## Compose

Each step is independent and imported by `run.ts`. You can reorder or add steps without changing MCP server code.
