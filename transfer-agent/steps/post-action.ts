import type { TransferAgentConfig } from "../config.js";
import type { McpSidecar } from "../src/mcp.js";
import type { PostActionResult } from "../src/types.js";

export async function runPostAction(
  mcp: McpSidecar,
  cfg: TransferAgentConfig,
): Promise<PostActionResult> {
  switch (cfg.POST_ACTION) {
    case "none":
      return { kind: "none" };

    case "get_balances": {
      const data = await mcp.callTool("starknet_get_balances", {
        tokens: [cfg.TRANSFER_TOKEN, "ETH"],
        address: cfg.STARKNET_ACCOUNT_ADDRESS,
      });
      return { kind: "get_balances", data };
    }

    case "call_contract": {
      if (!cfg.TOKEN_CONTRACT_ADDRESS) {
        throw new Error(
          "POST_ACTION=call_contract requires TOKEN_CONTRACT_ADDRESS in .env",
        );
      }
      const data = await mcp.callTool("starknet_call_contract", {
        contractAddress: cfg.TOKEN_CONTRACT_ADDRESS,
        entrypoint: "balance_of",
        calldata: [cfg.STARKNET_ACCOUNT_ADDRESS],
      });
      return { kind: "call_contract", data };
    }

    default:
      return { kind: "none" };
  }
}
