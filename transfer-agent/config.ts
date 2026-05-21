import path from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const booleanEnv = z
  .enum(["0", "1", "true", "false"])
  .transform((v) => v === "1" || v === "true");

const envSchema = z.object({
  STARKNET_RPC_URL: z.string().url(),
  STARKNET_ACCOUNT_ADDRESS: z
    .string()
    .regex(/^0x[0-9a-fA-F]+$/, "STARKNET_ACCOUNT_ADDRESS must be 0x-prefixed hex"),
  STARKNET_PRIVATE_KEY: z
    .string()
    .regex(/^0x[0-9a-fA-F]+$/, "STARKNET_PRIVATE_KEY must be 0x-prefixed hex"),
  TRANSFER_MCP_ENTRY: z.string().default(
    path.join(__dirname, "../starknet-agentic/packages/starknet-mcp-server/dist/index.js"),
  ),
  TRANSFER_TOKEN: z.string().default("STRK"),
  TRANSFER_RECIPIENT: z
    .string()
    .regex(/^0x[0-9a-fA-F]+$/)
    .optional(),
  TRANSFER_AMOUNT: z.string().default("0.1"),
  MIN_BALANCE_TO_TRANSFER: z.coerce.number().nonnegative().default(1),
  ALERT_BALANCE_THRESHOLD: z.coerce.number().nonnegative().default(0.5),
  TRANSFER_EXECUTE: booleanEnv.default("0"),
  POST_ACTION: z.enum(["get_balances", "call_contract", "none"]).default("get_balances"),
  TOKEN_CONTRACT_ADDRESS: z
    .string()
    .regex(/^0x[0-9a-fA-F]+$/)
    .optional(),
  TRANSFER_LOG_FILE: z.string().default("./transfer-agent-log.jsonl"),
});

export type TransferAgentConfig = z.infer<typeof envSchema>;

export function parseConfig(env: NodeJS.ProcessEnv = process.env): TransferAgentConfig {
  return envSchema.parse(env);
}

export function buildMcpEnv(cfg: TransferAgentConfig): Record<string, string> {
  return {
    STARKNET_RPC_URL: cfg.STARKNET_RPC_URL,
    STARKNET_ACCOUNT_ADDRESS: cfg.STARKNET_ACCOUNT_ADDRESS,
    STARKNET_PRIVATE_KEY: cfg.STARKNET_PRIVATE_KEY,
  };
}

export function resolveMcpEntry(cfg: TransferAgentConfig): string {
  return path.isAbsolute(cfg.TRANSFER_MCP_ENTRY)
    ? cfg.TRANSFER_MCP_ENTRY
    : path.resolve(__dirname, cfg.TRANSFER_MCP_ENTRY);
}
