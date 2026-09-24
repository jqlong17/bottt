import { execFile } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/** Same path the Swift CLI and SayServer use. */
export function socketPath(): string {
  return path.join(
    os.homedir(),
    "Library",
    "Application Support",
    "BOTTT",
    "bottt.sock",
  );
}

const APP_BUNDLE_ID = "local.bottt.desktop";

export class BotttNotRunningError extends Error {
  constructor() {
    super(
      "BOTTT is not running. Open BOTTT.app first — the MCP server only remotes the mouth; it does not launch the pet.",
    );
    this.name = "BotttNotRunningError";
  }
}

/**
 * Send a raw payload to the running app (same wire as `bottt say` / `bottt smile`).
 */
export function sendPayload(payload: string): Promise<void> {
  const sock = socketPath();
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(sock)) {
      reject(new BotttNotRunningError());
      return;
    }

    let settled = false;
    const fail = () => {
      if (settled) return;
      settled = true;
      reject(new BotttNotRunningError());
    };
    const ok = () => {
      if (settled) return;
      settled = true;
      resolve();
    };

    const client = net.createConnection(sock);
    client.setTimeout(2500);
    client.on("connect", () => {
      client.end(payload, "utf8");
    });
    client.on("timeout", () => {
      client.destroy();
      fail();
    });
    client.on("error", fail);
    client.on("close", (hadError) => {
      if (hadError) fail();
      else ok();
    });
  });
}

export async function speak(text: string): Promise<void> {
  const trimmed = text.trim();
  if (!trimmed) {
    throw new Error('speak requires a non-empty English "text" string.');
  }
  await sendPayload(trimmed);
}

export async function smile(): Promise<void> {
  await sendPayload("__bottt__:smile");
}

async function readDefault(key: string): Promise<string | null> {
  try {
    const { stdout } = await execFileAsync("defaults", [
      "read",
      APP_BUNDLE_ID,
      key,
    ]);
    const value = stdout.trim();
    return value.length > 0 ? value : null;
  } catch {
    return null;
  }
}

export type BotttStatus = {
  running: boolean;
  socket: string;
  speechMode: string;
  promptMode: string;
  look: string | null;
};

export async function getStatus(): Promise<BotttStatus> {
  const sock = socketPath();
  let running = false;
  if (fs.existsSync(sock)) {
    try {
      await new Promise<void>((resolve, reject) => {
        const client = net.createConnection(sock);
        client.setTimeout(800);
        client.on("connect", () => {
          client.end();
          resolve();
        });
        client.on("timeout", () => {
          client.destroy();
          reject(new Error("timeout"));
        });
        client.on("error", reject);
      });
      running = true;
    } catch {
      running = false;
    }
  }

  const speechMode = (await readDefault("bottt.speechMode")) ?? "voice";
  const promptMode = (await readDefault("bottt.promptMode")) ?? "summary";
  const look = await readDefault("bottt.look");

  return {
    running,
    socket: sock,
    speechMode,
    promptMode,
    look,
  };
}
