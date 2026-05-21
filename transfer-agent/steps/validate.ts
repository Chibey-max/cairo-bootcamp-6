import type { AlertState, TransferDecision } from "../src/types.js";

export function evaluateAlert(balance: number, threshold: number): AlertState {
  const triggered = balance < threshold;
  return {
    triggered,
    balance,
    threshold,
    message: triggered
      ? `ALERT: balance ${balance} is below threshold ${threshold}`
      : `Balance ${balance} is at or above alert threshold ${threshold}`,
  };
}

export function evaluateTransferDecision(
  balance: number,
  minBalanceToTransfer: number,
  transferAmount: string,
): TransferDecision {
  if (balance <= minBalanceToTransfer) {
    return {
      action: "SKIP",
      reason: `balance ${balance} is not greater than MIN_BALANCE_TO_TRANSFER (${minBalanceToTransfer})`,
      balance,
    };
  }

  const amountNum = Number.parseFloat(transferAmount);
  if (!Number.isFinite(amountNum) || amountNum <= 0) {
    return {
      action: "SKIP",
      reason: `invalid TRANSFER_AMOUNT "${transferAmount}"`,
      balance,
    };
  }

  if (balance < amountNum) {
    return {
      action: "SKIP",
      reason: `balance ${balance} is less than transfer amount ${amountNum}`,
      balance,
    };
  }

  return {
    action: "TRANSFER",
    balance,
    amount: transferAmount,
  };
}
