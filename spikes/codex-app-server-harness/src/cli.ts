import { pathToFileURL } from "node:url";

import type { RuntimeValidationRequest } from "./core/ai-provider-port.ts";
import { CodexAppServerAdapter } from "./adapters/codex/codex-app-server-adapter.ts";

export async function main(arguments_: readonly string[] = process.argv.slice(2)): Promise<number> {
  let request: RuntimeValidationRequest;
  try {
    request = parseArguments(arguments_);
  } catch {
    process.stderr.write("Usage: node src/cli.ts [--path PATH]\n");
    return 2;
  }

  const result = await new CodexAppServerAdapter().validateRuntime(request);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result.ok ? 0 : 1;
}

function parseArguments(arguments_: readonly string[]): RuntimeValidationRequest {
  const request: { path?: string } = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const option = arguments_[index];
    const value = arguments_[index + 1];
    if (!value) throw new Error("missing option value");
    if (option === "--path") request.path = value;
    else throw new Error("unknown option");
  }
  return request;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
