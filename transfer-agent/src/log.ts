import fs from "node:fs";
import path from "node:path";

export function logLine(
  level: "INFO" | "WARN" | "ERROR",
  message: string,
  data?: Record<string, unknown>,
): void {
  const payload = {
    timestamp: new Date().toISOString(),
    level,
    component: "transfer-agent",
    message,
    ...(data ?? {}),
  };
  const line = JSON.stringify(payload);
  if (level === "ERROR") {
    console.error(line);
  } else if (level === "WARN") {
    console.warn(line);
  } else {
    console.log(line);
  }
}

export function appendReceipt(filePath: string, receipt: Record<string, unknown>): void {
  const resolved = path.resolve(filePath);
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  fs.appendFileSync(resolved, `${JSON.stringify(receipt)}\n`, "utf8");
  logLine("INFO", "Receipt appended", { file: resolved });
}
