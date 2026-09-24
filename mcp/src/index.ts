#!/usr/bin/env node
/**
 * BOTTT MCP server (stdio).
 * Talks to the running BOTTT.app over the same Unix socket as `bottt say`.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import {
  BotttNotRunningError,
  getStatus,
  smile as doSmile,
  speak as doSpeak,
} from "./bottt.js";

const server = new McpServer({
  name: "bottt",
  version: "1.0.0",
});

function toolError(err: unknown) {
  const message =
    err instanceof Error ? err.message : typeof err === "string" ? err : String(err);
  return {
    content: [{ type: "text" as const, text: message }],
    isError: true,
  };
}

server.registerTool(
  "speak",
  {
    title: "Speak",
    description:
      "Make BOTTT say a short English sentence (same as `bottt say \"...\"`). Requires BOTTT.app to be open.",
    inputSchema: {
      text: z
        .string()
        .describe("Short English sentence for BOTTT to speak or caption."),
    },
  },
  async ({ text }) => {
    try {
      await doSpeak(text);
      return {
        content: [
          {
            type: "text" as const,
            text: `Spoke: ${text.trim()}`,
          },
        ],
      };
    } catch (err) {
      return toolError(err);
    }
  },
);

server.registerTool(
  "smile",
  {
    title: "Smile",
    description:
      "Flash BOTTT's happy face (same as `bottt smile`). Requires BOTTT.app to be open.",
  },
  async () => {
    try {
      await doSmile();
      return {
        content: [{ type: "text" as const, text: "Smiled." }],
      };
    } catch (err) {
      return toolError(err);
    }
  },
);

server.registerTool(
  "get_status",
  {
    title: "Get status",
    description:
      "Report whether BOTTT.app is running and the last-saved speech/prompt modes from preferences.",
  },
  async () => {
    try {
      const status = await getStatus();
      const lines = [
        `running: ${status.running ? "yes" : "no"}`,
        `speechMode: ${status.speechMode}`,
        `promptMode: ${status.promptMode}`,
        status.look ? `look: ${status.look}` : null,
        `socket: ${status.socket}`,
      ].filter(Boolean);
      return {
        content: [{ type: "text" as const, text: lines.join("\n") }],
      };
    } catch (err) {
      return toolError(err);
    }
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr only — stdout is the MCP JSON-RPC channel.
  console.error("bottt MCP server ready (stdio)");
}

main().catch((err) => {
  console.error(err instanceof BotttNotRunningError ? err.message : err);
  process.exit(1);
});
