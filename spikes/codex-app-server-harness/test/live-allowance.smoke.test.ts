import assert from "node:assert/strict";
import test from "node:test";
import { main } from "../src/cli.ts";

test("managed allowance validation is opt-in", { skip: process.env.PROJECTOS_LIVE_ALLOWANCE === "1" ? false : "set PROJECTOS_LIVE_ALLOWANCE=1" }, async () => {
  const status = await main(["allowance-validate"]);
  assert.ok(status === 0 || status === 1);
});
