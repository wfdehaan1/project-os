import { chmod, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

export type FakeCodexBehavior =
  | "success"
  | "reject"
  | "malformed"
  | "wrong-id-then-match"
  | "wrong-id-only"
  | "duplicate-match"
  | "semantic-notification"
  | "semantic-notification-only"
  | "semantic-request"
  | "forbidden-request"
  | "unknown-method"
  | "request-before-initialize"
  | "timeout-once"
  | "oversized"
  | "repeated-initialize"
  | "leader-exits-child-runs"
  | "version-leader-exits-child-runs"
  | "version-probe-failure"
  | "late-old-message"
  | "build-drift"
  | "schema-drift"
  | "experimental-output"
  | "generator-crash"
  | "generator-timeout"
  | "generator-nonzero"
  | "generator-malformed"
  | "generator-missing"
  | "generator-extra"
  | "generator-oversized"
  | "eof"
  | "timeout"
  | "unexpected-exit"
  | "ignore-term";

export async function createFakeCodexRuntime(
  directory: string,
  behavior: FakeCodexBehavior,
  marker?: string,
): Promise<{
  executablePath: string;
  transcriptPath: string;
  pidPath: string;
  descendantPidPath: string;
  behaviorPath: string;
}> {
  await mkdir(directory, { recursive: true });
  const executablePath = join(directory, "codex");
  const transcriptPath = join(directory, "transcript.jsonl");
  const pidPath = join(directory, "pid.txt");
  const descendantPidPath = join(directory, "descendant-pid.txt");
  const behaviorPath = join(directory, "behavior.txt");
  await writeFile(behaviorPath, `${behavior}\n`, { mode: 0o600 });
  const script = `#!${process.execPath}
    import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
    import { spawn } from "node:child_process";
const codexHome = process.env.CODEX_HOME ?? "";
const profileBehaviorPath = codexHome + "/synthetic-behavior.txt";
const profileMarkerPath = codexHome + "/synthetic-marker.txt";
const behavior = readFileSync(
  existsSync(profileBehaviorPath) ? profileBehaviorPath : ${JSON.stringify(behaviorPath)},
  "utf8",
).trim();
const configuredMarker = ${JSON.stringify(marker ?? null)};
const marker = existsSync(profileMarkerPath)
  ? readFileSync(profileMarkerPath, "utf8").trim()
  : configuredMarker;
    const transcript = ${JSON.stringify(transcriptPath)};
    const pidPath = ${JSON.stringify(pidPath)};
    const descendantPidPath = ${JSON.stringify(descendantPidPath)};
    const restartCounterPath = ${JSON.stringify(join(directory, "restart-counter.txt"))};
writeFileSync(pidPath, String(process.pid), { mode: 0o600 });
const startRecord = { argv: process.argv.slice(2), pid: process.pid };
if (marker !== null) Object.assign(startRecord, { marker, codexHome: process.env.CODEX_HOME ?? null, syntheticSession: marker });
appendFileSync(transcript, JSON.stringify(startRecord) + "\\n");
if (process.argv[2] === "--version") {
  if (behavior === "version-probe-failure") process.exit(23);
  if (behavior === "version-leader-exits-child-runs") {
    const descendant = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { stdio: "ignore" });
    writeFileSync(descendantPidPath, String(descendant.pid), { mode: 0o600 });
    descendant.unref();
  }
  process.stdout.write(behavior === "build-drift" ? "codex-cli 0.0.0\\n" : "codex-cli 9.8.7\\n");
  process.exit(0);
}
if (process.argv[2] === "app-server" && process.argv[3]?.startsWith("generate-")) {
  if (behavior === "generator-crash") process.kill(process.pid, "SIGKILL");
  if (behavior === "generator-timeout") await new Promise(() => setInterval(() => {}, 1000));
  if (behavior === "generator-nonzero") process.exit(23);
  const output = process.argv[5];
  mkdirSync(output, { recursive: true, mode: 0o700 });
  if (process.argv[3] === "generate-json-schema") {
    const schema = (title, methods) => JSON.stringify({ title, oneOf: methods.map((method) => ({ type: "object", properties: { method: { type: "string", enum: [method] } } })) }, null, 2) + "\\n";
    if (behavior === "generator-malformed") {
      writeFileSync(output + "/ClientRequest.json", "{malformed");
      process.exit(0);
    }
    if (behavior === "generator-oversized") {
      writeFileSync(output + "/oversized.json", "x".repeat(16 * 1024 * 1024 + 1));
      process.exit(0);
    }
    writeFileSync(output + "/ClientRequest.json", schema("ClientRequest", behavior === "experimental-output" ? ["experimental/thread", "initialize"] : ["initialize"]));
    writeFileSync(output + "/ClientNotification.json", schema("ClientNotification", ["initialized"]));
    writeFileSync(output + "/ServerNotification.json", schema("ServerNotification", ["error", "warning"]));
    if (behavior !== "generator-missing") writeFileSync(output + "/ServerRequest.json", schema("ServerRequest", ["item/tool/call"]));
    if (behavior === "generator-extra") writeFileSync(output + "/Experimental.json", schema("Experimental", ["experimental/thread"]));
  } else {
    writeFileSync(output + "/ClientRequest.ts", behavior === "schema-drift" ? 'export type ClientRequest = "initialize" | "thread/start";\\n' : 'export type ClientRequest = "initialize";\\n');
    writeFileSync(output + "/ServerRequest.ts", 'export type ServerRequest = "item/tool/call";\\n');
  }
  process.exit(0);
}
if (behavior === "unexpected-exit") process.exit(23);
if (behavior === "eof") process.exit(0);
if (behavior === "ignore-term") process.on("SIGTERM", () => {});
if (behavior === "request-before-initialize") {
  process.stdout.write(JSON.stringify({ id: 88, method: "item/tool/call", params: { secret: "not-persisted" } }) + "\\n");
}
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
      if (behavior === "timeout-once" && !existsSync(restartCounterPath)) {
        writeFileSync(restartCounterPath, "failed-once", { mode: 0o600 });
        continue;
      }
      if (behavior === "late-old-message" && !existsSync(restartCounterPath)) {
        writeFileSync(restartCounterPath, "old-generation-started", { mode: 0o600 });
        const delayed = spawn(process.execPath, ["-e", 'setTimeout(() => process.stdout.write(JSON.stringify({ id: 1, result: { userAgent: "late-old" } }) + "\\n"), 700); setTimeout(() => {}, 1000);'], { stdio: ["ignore", process.stdout, "ignore"] });
        writeFileSync(descendantPidPath, String(delayed.pid), { mode: 0o600 });
        delayed.unref();
        continue;
      }
      if (behavior === "oversized") {
        process.stdout.write(JSON.stringify({ method: "future/event", params: { value: "x".repeat(1024 * 1024) } }) + "\\n");
        continue;
      }
      if (behavior === "repeated-initialize") {
        process.stdout.write(JSON.stringify({ method: "initialize", params: {} }) + "\\n");
        continue;
      }
      if (behavior === "semantic-notification" || behavior === "semantic-notification-only") {
        process.stdout.write(JSON.stringify({ method: "warning", params: { secret: "not-persisted" } }) + "\\n");
      }
      if (behavior === "semantic-notification-only") continue;
      if (behavior === "semantic-request") {
        process.stdout.write(JSON.stringify({ id: 78, method: "warning", params: { secret: "not-persisted" } }) + "\\n");
        continue;
      }
      if (behavior === "forbidden-request") {
        process.stdout.write(JSON.stringify({ id: 77, method: "item/tool/call", params: { secret: "not-persisted" } }) + "\\n");
        continue;
      }
      if (behavior === "unknown-method") {
        process.stdout.write(JSON.stringify({ method: "future/event", params: { secret: "not-persisted" } }) + "\\n");
        continue;
      }
      if (behavior === "wrong-id-only") {
        process.stdout.write(JSON.stringify({ id: 999, result: { userAgent: "unrelated" } }) + "\\n");
        continue;
      }
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
      if (behavior === "success" || behavior === "wrong-id-then-match" || behavior === "semantic-notification" || behavior === "timeout-once" || behavior === "late-old-message") setImmediate(() => process.exit(0));
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
  return { executablePath, transcriptPath, pidPath, descendantPidPath, behaviorPath };
}
