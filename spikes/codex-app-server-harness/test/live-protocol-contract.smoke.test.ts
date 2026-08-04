import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import test from "node:test";

const requested = process.env.PROJECTOS_LIVE_PROTOCOL === "1";
const execFileAsync = promisify(execFile);
const harnessRoot = dirname(fileURLToPath(new URL("../package.json", import.meta.url)));
const evidenceRoot = join(harnessRoot, ".evidence");

test(
  "installed exact Codex contract passes through the real CLI and retains structural evidence",
  { skip: requested ? false : "set PROJECTOS_LIVE_PROTOCOL=1" },
  async () => {
    assert.equal(
      process.platform,
      "darwin",
      "PROJECTOS_LIVE_PROTOCOL=1 requires macOS and must fail explicitly elsewhere",
    );
    const before = new Set(await directoryNames(evidenceRoot));
    const { stdout, stderr } = await execFileAsync(
      process.execPath,
      [
        "--experimental-strip-types",
        fileURLToPath(new URL("../src/cli.ts", import.meta.url)),
        "protocol-validate",
      ],
      {
        cwd: harnessRoot,
        env: { ...process.env, PROJECTOS_LIVE_PROTOCOL: "1" },
        maxBuffer: 1024 * 1024,
      },
    );
    assert.equal(stderr, "");
    assert.doesNotMatch(stdout, /private\.json|protocol-private|resolvedExecutablePath|stderrFingerprint/iu);
    const result = JSON.parse(stdout) as {
      ok: boolean;
      compatibilityStatus?: string;
      manifestId?: string;
      providerActionEnabled?: boolean;
      canonicalStateOperationEnabled?: boolean;
    };
    assert.equal(result.ok, true);
    assert.equal(result.compatibilityStatus, "compatible");
    assert.equal(result.providerActionEnabled, false);
    assert.equal(result.canonicalStateOperationEnabled, false);

    const created = (await directoryNames(evidenceRoot)).filter((name) => !before.has(name));
    assert.equal(created.length, 1);
    const runDirectory = join(evidenceRoot, created[0]!);
    assert.deepEqual((await readdir(runDirectory)).sort(), [
      "private.json",
      "protocol-private.json",
      "protocol-schemas",
      "protocol-summary.json",
      "protocol-transcript.json",
      "summary.json",
    ]);
    const summary = JSON.parse(await readFile(join(runDirectory, "protocol-summary.json"), "utf8")) as {
      manifestId: string;
      compatibilityOutcome: string;
      enabledDispatch: { clientRequests: string[]; clientNotifications: string[] };
    };
    assert.equal(summary.manifestId, result.manifestId);
    assert.equal(summary.compatibilityOutcome, "compatible");
    assert.deepEqual(summary.enabledDispatch, {
      clientRequests: ["initialize"],
      clientNotifications: ["initialized"],
    });
    const transcript = JSON.parse(
      await readFile(join(runDirectory, "protocol-transcript.json"), "utf8"),
    ) as Array<{ direction: string; method: string; classification: string }>;
    assert.deepEqual(
      transcript.map(({ direction, method, classification }) => ({ direction, method, classification })),
      [
        { direction: "outbound_request", method: "initialize", classification: "sent_experimental_api_disabled" },
        { direction: "inbound_response", method: "initialize", classification: "matched" },
        { direction: "outbound_notification", method: "initialized", classification: "sent" },
      ],
    );
    assert.doesNotMatch(JSON.stringify(transcript), /account|thread|turn|tool|params|payload/iu);
  },
);

async function directoryNames(path: string): Promise<string[]> {
  try {
    return (await readdir(path, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch (error: unknown) {
    if (isNodeError(error) && error.code === "ENOENT") return [];
    throw error;
  }
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
