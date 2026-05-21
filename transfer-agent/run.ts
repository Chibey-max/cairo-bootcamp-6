#!/usr/bin/env -S npx tsx
/**
 * Test 2 — Automated Transfer & Multi-Step Agent Workflow
 *
 * 1. Fetch wallet balance (starknet_get_balance)
 * 2. Validate transfer condition (balance > MIN_BALANCE_TO_TRANSFER)
 * 3. Transfer if allowed (starknet_transfer, dry-run then optional execute)
 * 4. Post-action second MCP step (get_balances or call_contract)
 * 5. Log execution receipt to JSONL
 * 6. Alert when balance < ALERT_BALANCE_THRESHOLD
 */

import dotenv from "dotenv";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { buildMcpEnv, parseConfig, resolveMcpEntry } from "./config.js";
import { fetchBalance } from "./steps/balance.js";
import { runPostAction } from "./steps/post-action.js";
import { runTransferStep } from "./steps/transfer.js";
import { evaluateAlert, evaluateTransferDecision } from "./steps/validate.js";
import { appendReceipt, logLine } from "./src/log.js";
import { McpSidecar } from "./src/mcp.js";
import { notifyAlert, notifyStep, notifyTransaction } from "./src/notify.js";
import type { RunReceipt } from "./src/types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, ".env"), quiet: true });

async function main(): Promise<void> {
  const cfg = parseConfig();
  const mcpEntry = resolveMcpEntry(cfg);

  if (!fs.existsSync(mcpEntry)) {
    throw new Error(
      `MCP server not found at ${mcpEntry}. Build it: cd ../starknet-agentic && pnpm install && pnpm build`,
    );
  }

  if (!cfg.TRANSFER_RECIPIENT) {
    throw new Error("Set TRANSFER_RECIPIENT in transfer-agent/.env");
  }

  logLine("INFO", "Starting transfer agent", {
    token: cfg.TRANSFER_TOKEN,
    minBalanceToTransfer: cfg.MIN_BALANCE_TO_TRANSFER,
    alertThreshold: cfg.ALERT_BALANCE_THRESHOLD,
    execute: cfg.TRANSFER_EXECUTE,
    postAction: cfg.POST_ACTION,
    account: cfg.STARKNET_ACCOUNT_ADDRESS,
  });

  const mcp = new McpSidecar(mcpEntry, buildMcpEnv(cfg));

  try {
    await mcp.connect("transfer-agent");

    // Step 1: fetch balance
    const { result: balanceRaw, balanceNumber } = await fetchBalance(
      mcp,
      cfg.TRANSFER_TOKEN,
      cfg.STARKNET_ACCOUNT_ADDRESS,
    );
    logLine("INFO", "Balance fetched", {
      token: balanceRaw.token,
      balance: balanceNumber,
      raw: balanceRaw.balance,
    });
    notifyStep("1_fetch_balance", "Wallet balance loaded", {
      token: balanceRaw.token,
      balance: balanceNumber,
      address: cfg.STARKNET_ACCOUNT_ADDRESS,
    });

    // Step 6 (early): alert on low balance
    const alert = evaluateAlert(balanceNumber, cfg.ALERT_BALANCE_THRESHOLD);
    if (alert.triggered) {
      notifyAlert(alert.message, alert.balance, alert.threshold);
      logLine("WARN", alert.message, {
        balance: alert.balance,
        threshold: alert.threshold,
      });
    } else {
      logLine("INFO", alert.message);
    }

    // Step 2: validate transfer condition
    const decision = evaluateTransferDecision(
      balanceNumber,
      cfg.MIN_BALANCE_TO_TRANSFER,
      cfg.TRANSFER_AMOUNT,
    );
    logLine("INFO", "Transfer decision", { decision });
    notifyStep(
      "2_validate",
      decision.action === "TRANSFER"
        ? `Condition passed: balance > ${cfg.MIN_BALANCE_TO_TRANSFER}`
        : `Condition failed: ${decision.action === "SKIP" ? decision.reason : "unknown"}`,
      {
        action: decision.action,
        minRequired: cfg.MIN_BALANCE_TO_TRANSFER,
        currentBalance: balanceNumber,
        transferAmount: cfg.TRANSFER_AMOUNT,
      },
    );

    if (decision.action === "SKIP") {
      notifyTransaction({
        kind: "skipped",
        token: cfg.TRANSFER_TOKEN,
        amount: cfg.TRANSFER_AMOUNT,
        recipient: cfg.TRANSFER_RECIPIENT,
        error: decision.reason,
        rpcUrl: cfg.STARKNET_RPC_URL,
      });
    }

    // Step 3: conditional transfer
    const transfer = await runTransferStep(mcp, decision, {
      recipient: cfg.TRANSFER_RECIPIENT,
      token: cfg.TRANSFER_TOKEN,
      execute: cfg.TRANSFER_EXECUTE,
      rpcUrl: cfg.STARKNET_RPC_URL,
    });
    if (transfer.error) {
      logLine("ERROR", "Transfer step failed", { error: transfer.error });
    } else if (transfer.executed) {
      logLine("INFO", "Transfer submitted", { txHash: transfer.txHash });
    } else if (decision.action === "TRANSFER") {
      logLine("INFO", "Transfer simulated (dry-run). Set TRANSFER_EXECUTE=1 to submit.", {
        dryRun: transfer.dryRun,
      });
    }

    // Step 4: second MCP call / sub-workflow
    const postAction = await runPostAction(mcp, cfg);
    logLine("INFO", "Post-action complete", { kind: postAction.kind });
    notifyStep("4_post_action", `Secondary MCP call finished`, {
      kind: postAction.kind,
      postAction: cfg.POST_ACTION,
    });

    // Step 5: log receipt
    const receipt: RunReceipt = {
      timestamp: new Date().toISOString(),
      token: cfg.TRANSFER_TOKEN,
      balanceBefore: balanceNumber,
      alert,
      decision,
      transfer,
      postAction,
    };

    const logPath = path.resolve(__dirname, cfg.TRANSFER_LOG_FILE);
    appendReceipt(logPath, receipt);
    notifyStep("5_log", "Execution receipt saved", {
      file: logPath,
      decision: decision.action,
      transferExecuted: transfer.executed,
      txHash: transfer.txHash,
    });

    notifyStep("complete", "All workflow steps finished", {
      decision: decision.action,
      alertTriggered: alert.triggered,
      transferExecuted: transfer.executed,
      executeMode: cfg.TRANSFER_EXECUTE,
    });

    logLine("INFO", "Transfer agent finished", {
      decision: decision.action,
      alert: alert.triggered,
      transferExecuted: transfer.executed,
    });
  } finally {
    await mcp.close();
  }
}

main().catch((err) => {
  const message = err instanceof Error ? err.message : String(err);
  logLine("ERROR", "Transfer agent failed", { error: message });
  process.exit(1);
});
