import assert from "node:assert/strict";
import test from "node:test";

import { main } from "../src/cli.ts";

test("interactive managed authentication is opt-in", { skip: process.env.PROJECTOS_LIVE_AUTH !== "1" }, async () => {
  let output = "";
  const exitCode = await main(["auth-validate", "--interactive"], {
    stdout: { write: (value) => { output += String(value); return true; } },
  });
  assert.equal(exitCode, 0, output);
  assert.doesNotMatch(output, /https?:\/\/|token|authorization|account(?:id|_id)?/iu);
});
