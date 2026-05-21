export type BalanceResult = {
  address: string;
  token: string;
  tokenAddress?: string;
  balance: string;
  raw?: string;
  decimals?: number;
};

export type TransferDecision =
  | { action: "SKIP"; reason: string; balance: number }
  | { action: "TRANSFER"; balance: number; amount: string };

export type AlertState = {
  triggered: boolean;
  balance: number;
  threshold: number;
  message: string;
};

export type TransferStepResult = {
  executed: boolean;
  dryRun: boolean;
  txHash?: string;
  error?: string;
  raw?: unknown;
};

export type PostActionResult = {
  kind: "get_balances" | "call_contract" | "none";
  data?: unknown;
};

export type RunReceipt = {
  timestamp: string;
  token: string;
  balanceBefore: number;
  alert: AlertState;
  decision: TransferDecision;
  transfer: TransferStepResult;
  postAction: PostActionResult;
};
