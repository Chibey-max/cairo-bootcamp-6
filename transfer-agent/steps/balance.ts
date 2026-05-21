import type { McpSidecar } from "../src/mcp.js";
import type { BalanceResult } from "../src/types.js";

export async function fetchBalance(
  mcp: McpSidecar,
  token: string,
  address?: string,
): Promise<{ result: BalanceResult; balanceNumber: number }> {
  const args: Record<string, unknown> = { token };
  if (address) {
    args.address = address;
  }

  const raw = await mcp.callTool("starknet_get_balance", args);
  const result = raw as BalanceResult;

  const balanceNumber = Number.parseFloat(result.balance);
  if (!Number.isFinite(balanceNumber)) {
    throw new Error(`Could not parse balance "${result.balance}" for token ${token}`);
  }

  return { result, balanceNumber };
}
