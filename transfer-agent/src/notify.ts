export type TransactionNotifyKind =
  | "simulated"
  | "submitted"
  | "confirmed"
  | "failed"
  | "skipped";

export type TransactionNotifyInput = {
  kind: TransactionNotifyKind;
  token: string;
  amount: string;
  recipient?: string;
  txHash?: string;
  rpcUrl?: string;
  error?: string;
  dryRun?: boolean;
};

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";

function terminalNotifyEnabled(): boolean {
  return process.env.TERMINAL_NOTIFY !== "0";
}

function terminalBellEnabled(): boolean {
  return process.env.TERMINAL_BELL !== "0";
}

function explorerBaseUrl(rpcUrl?: string): string {
  const rpc = (rpcUrl ?? "").toLowerCase();
  if (rpc.includes("mainnet") && !rpc.includes("sepolia")) {
    return "https://starkscan.co/tx/";
  }
  return "https://sepolia.starkscan.co/tx/";
}

function kindStyle(kind: TransactionNotifyKind): { label: string; color: string } {
  switch (kind) {
    case "simulated":
      return { label: "TRANSACTION (dry-run / simulated)", color: YELLOW };
    case "submitted":
      return { label: "TRANSACTION SUBMITTED", color: CYAN };
    case "confirmed":
      return { label: "TRANSACTION CONFIRMED", color: GREEN };
    case "failed":
      return { label: "TRANSACTION FAILED", color: RED };
    case "skipped":
      return { label: "TRANSACTION SKIPPED", color: DIM };
  }
}

function writeBlock(lines: string[]): void {
  const bar = "═".repeat(56);
  console.log(`\n${bar}`);
  for (const line of lines) {
    console.log(line);
  }
  console.log(`${bar}\n`);
}

/** Loud terminal notification for any transfer-agent transaction event. */
export function notifyTransaction(input: TransactionNotifyInput): void {
  if (!terminalNotifyEnabled()) {
    return;
  }

  const { label, color } = kindStyle(input.kind);
  const lines: string[] = [
    `${color}${BOLD}  ${label}${RESET}`,
    `  ${DIM}Token:${RESET} ${input.token}   ${DIM}Amount:${RESET} ${input.amount}`,
  ];

  if (input.recipient) {
    lines.push(`  ${DIM}Recipient:${RESET} ${input.recipient}`);
  }

  if (input.txHash) {
    const explorer = `${explorerBaseUrl(input.rpcUrl)}${input.txHash}`;
    lines.push(`  ${DIM}Tx hash:${RESET} ${input.txHash}`);
    lines.push(`  ${DIM}Explorer:${RESET} ${explorer}`);
  }

  if (input.dryRun) {
    lines.push(`  ${YELLOW}No on-chain tx (simulation only)${RESET}`);
  }

  if (input.error) {
    lines.push(`  ${RED}Error: ${input.error}${RESET}`);
  }

  writeBlock(lines);

  if (terminalBellEnabled() && (input.kind === "confirmed" || input.kind === "failed")) {
    process.stdout.write("\x07");
  }
}

export type WorkflowStep =
  | "1_fetch_balance"
  | "2_validate"
  | "3_transfer"
  | "4_post_action"
  | "5_log"
  | "6_alert"
  | "complete";

/** Notification for each Test 2 workflow step. */
export function notifyStep(
  step: WorkflowStep,
  title: string,
  details: Record<string, string | number | boolean | undefined>,
): void {
  if (!terminalNotifyEnabled()) {
    return;
  }

  const stepLabels: Record<WorkflowStep, string> = {
    "1_fetch_balance": "STEP 1 — Fetch wallet balance",
    "2_validate": "STEP 2 — Validate transfer condition",
    "3_transfer": "STEP 3 — Transfer tokens",
    "4_post_action": "STEP 4 — Call another function/agent",
    "5_log": "STEP 5 — Log execution result",
    "6_alert": "STEP 6 — Balance threshold alert",
    complete: "WORKFLOW COMPLETE",
  };

  const color =
    step === "6_alert"
      ? YELLOW
      : step === "complete"
        ? GREEN
        : CYAN;

  const lines: string[] = [
    `${color}${BOLD}  ${stepLabels[step]}${RESET}`,
    `  ${title}`,
  ];

  for (const [key, value] of Object.entries(details)) {
    if (value !== undefined) {
      lines.push(`  ${DIM}${key}:${RESET} ${value}`);
    }
  }

  writeBlock(lines);
}

/** Terminal notification for balance alerts (not a tx, but user-visible). */
export function notifyAlert(message: string, balance: number, threshold: number): void {
  notifyStep("6_alert", message, { balance, threshold });
  if (terminalBellEnabled()) {
    process.stdout.write("\x07");
  }
}
