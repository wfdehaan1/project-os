import assert from "node:assert/strict";
import test from "node:test";

import { CodexAppServerAdapter } from "../src/adapters/codex/codex-app-server-adapter.ts";

const enabled = process.env.PROJECTOS_LIVE_CODEX === "1" && process.platform === "darwin";

test(
  "installed Codex initializes in isolation and shuts down without provider work",
  { skip: enabled ? false : "set PROJECTOS_LIVE_CODEX=1 on macOS" },
  async () => {
    const result = await new CodexAppServerAdapter().validateRuntime({});
    assert.equal(result.ok, true, result.ok ? undefined : `${result.code}:${result.correlationId}`);
    if (result.ok) {
      assert.equal(result.providerActionEnabled, false);
      assert.equal(result.canonicalStateOperationEnabled, false);
      assert.ok(result.runtimeVersion.length > 0);
    }
  },
);
