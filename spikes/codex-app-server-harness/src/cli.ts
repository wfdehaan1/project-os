import { pathToFileURL } from "node:url";

import type {
  AiProviderPort,
  RuntimeValidationRequest,
} from "./core/ai-provider-port.ts";
import { CodexAppServerAdapter } from "./adapters/codex/codex-app-server-adapter.ts";

export interface CliDependencies {
  readonly provider?: AiProviderPort;
  readonly stdout?: Pick<NodeJS.WriteStream, "write">;
  readonly stderr?: Pick<NodeJS.WriteStream, "write">;
}

export async function main(
  arguments_: readonly string[] = process.argv.slice(2),
  dependencies: CliDependencies = {},
): Promise<number> {
  const stdout = dependencies.stdout ?? process.stdout;
  const stderr = dependencies.stderr ?? process.stderr;
  let request: RuntimeValidationRequest;
  try {
    request = parseArguments(arguments_);
  } catch {
    stderr.write(
      "Usage: node src/cli.ts [protocol-validate] [--path PATH] [--restart]\n",
    );
    return 2;
  }

  const result = await (dependencies.provider ?? new CodexAppServerAdapter()).validateRuntime(request);
  stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result.ok ? 0 : 1;
}

export function parseArguments(arguments_: readonly string[]): RuntimeValidationRequest {
  const request: { path?: string; restart?: boolean } = {};
  let index = 0;
  if (arguments_[0] === "protocol-validate") index = 1;
  else if (arguments_[0] && !arguments_[0].startsWith("--")) throw new Error("unknown command");
  while (index < arguments_.length) {
    const option = arguments_[index];
    if (option === "--restart") {
      if (request.restart) throw new Error("duplicate option");
      request.restart = true;
      index += 1;
      continue;
    }
    if (option === "--path") {
      const value = arguments_[index + 1];
      if (!value || value.startsWith("--") || request.path) throw new Error("invalid path option");
      request.path = value;
      index += 2;
      continue;
    }
    throw new Error("unknown option");
  }
  return request;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
