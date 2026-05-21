import type { McpSidecar } from "../src/mcp.js";
import { notifyTransaction } from "../src/notify.js";
import type { TransferDecision, TransferStepResult } from "../src/types.js";

function extractTxHash(raw: unknown): string | undefined {
  if (typeof raw !== "object" || raw === null) {
    return undefined;
  }
  const record = raw as Record<string, unknown>;
  for (const key of ["transactionHash", "transaction_hash", "txHash", "tx_hash"]) {
    const value = record[key];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  return undefined;
}

export async function runTransferStep(
  mcp: McpSidecar,
  decision: TransferDecision,
  params: {
    recipient: string;
    token: string;
    execute: boolean;
    rpcUrl?: string;
  },
): Promise<TransferStepResult> {
  if (decision.action !== "TRANSFER") {
    return { executed: false, dryRun: true };
  }

  const baseArgs = {
    recipient: params.recipient,
    token: params.token,
    amount: decision.amount,
  };

  try {
    const simulated = await mcp.callTool("starknet_transfer", {
      ...baseArgs,
      dryRun: true,
    });

    if (!params.execute) {
      notifyTransaction({
        kind: "simulated",
        token: params.token,
        amount: decision.amount,
        recipient: params.recipient,
        dryRun: true,
        rpcUrl: params.rpcUrl,
      });
      return {
        executed: false,
        dryRun: true,
        raw: simulated,
      };
    }

    notifyTransaction({
      kind: "submitted",
      token: params.token,
      amount: decision.amount,
      recipient: params.recipient,
      rpcUrl: params.rpcUrl,
    });

    const submitted = await mcp.callTool("starknet_transfer", baseArgs);
    const txHash = extractTxHash(submitted);

    notifyTransaction({
      kind: "confirmed",
      token: params.token,
      amount: decision.amount,
      recipient: params.recipient,
      txHash,
      rpcUrl: params.rpcUrl,
    });

    return {
      executed: true,
      dryRun: false,
      txHash,
      raw: submitted,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    notifyTransaction({
      kind: "failed",
      token: params.token,
      amount: decision.amount,
      recipient: params.recipient,
      error: message,
      rpcUrl: params.rpcUrl,
    });
    return {
      executed: false,
      dryRun: !params.execute,
      error: message,
    };
  }
}
