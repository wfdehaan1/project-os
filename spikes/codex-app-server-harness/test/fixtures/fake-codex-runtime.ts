import { chmod, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

export type FakeCodexBehavior =
  | "success"
  | "reject"
  | "malformed"
  | "wrong-id-then-match"
  | "duplicate-match"
  | "leader-exits-child-runs"
  | "eof"
  | "timeout"
  | "unexpected-exit"
  | "ignore-term";

export async function createFakeCodexRuntime(
  directory: string,
  behavior: FakeCodexBehavior,
): Promise<{
  executablePath: string;
  transcriptPath: string;
  pidPath: string;
  descendantPidPath: string;
}> {
  await mkdir(directory, { recursive: true });
  const executablePath = join(directory, "codex");
  const transcriptPath = join(directory, "transcript.jsonl");
  const pidPath = join(directory, "pid.txt");
  const descendantPidPath = join(directory, "descendant-pid.txt");
  const script = `#!${process.execPath}
    import { appendFileSync, writeFileSync } from "node:fs";
    import { spawn } from "node:child_process";
const behavior = ${JSON.stringify(behavior)};
    const transcript = ${JSON.stringify(transcriptPath)};
    const pidPath = ${JSON.stringify(pidPath)};
    const descendantPidPath = ${JSON.stringify(descendantPidPath)};
writeFileSync(pidPath, String(process.pid), { mode: 0o600 });
appendFileSync(transcript, JSON.stringify({ argv: process.argv.slice(2) }) + "\\n");
if (process.argv[2] === "--version") {
  process.stdout.write("codex-cli 9.8.7\\n");
  process.exit(0);
}
if (behavior === "unexpected-exit") process.exit(23);
if (behavior === "eof") process.exit(0);
if (behavior === "ignore-term") process.on("SIGTERM", () => {});
let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  while (buffer.includes("\\n")) {
    const index = buffer.indexOf("\\n");
    const line = buffer.slice(0, index);
    buffer = buffer.slice(index + 1);
    if (!line) continue;
    appendFileSync(transcript, line + "\\n");
    if (behavior === "timeout" || behavior === "ignore-term") continue;
    if (behavior === "malformed") {
      process.stdout.write("{malformed\\n");
      continue;
    }
    const message = JSON.parse(line);
    if (message.method === "initialize") {
      if (behavior === "reject") {
        process.stdout.write(JSON.stringify({ id: message.id, error: { code: -1 } }) + "\\n");
      } else {
        if (behavior === "wrong-id-then-match") {
          process.stdout.write(JSON.stringify({ id: 999, result: { userAgent: "unrelated" } }) + "\\n");
        }
        const response = JSON.stringify({ id: message.id, result: { userAgent: "fake-codex" } }) + "\\n";
        process.stdout.write(behavior === "duplicate-match" ? response + response : response);
      }
    } else if (message.method === "initialized") {
      if (behavior === "success" || behavior === "wrong-id-then-match") setImmediate(() => process.exit(0));
      if (behavior === "leader-exits-child-runs") {
        const descendant = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { stdio: "ignore" });
        writeFileSync(descendantPidPath, String(descendant.pid), { mode: 0o600 });
        descendant.unref();
        setImmediate(() => process.exit(0));
      }
    }
  }
});
setInterval(() => {}, 1000);
`;
  await writeFile(executablePath, script, { mode: 0o700 });
  await chmod(executablePath, 0o700);
  return { executablePath, transcriptPath, pidPath, descendantPidPath };
}
