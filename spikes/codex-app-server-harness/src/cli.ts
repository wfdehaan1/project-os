import { pathToFileURL } from "node:url";
import { spawn } from "node:child_process";

import type {
  AiProviderPort,
  AllowanceValidationRequest,
  PreventiveExecutionContainmentRequest,
  RuntimeValidationRequest,
  StructuredOutputValidationRequest,
} from "./core/ai-provider-port.ts";
import { CodexAppServerAdapter } from "./adapters/codex/codex-app-server-adapter.ts";

type CliRequest = RuntimeValidationRequest & AllowanceValidationRequest & StructuredOutputValidationRequest & PreventiveExecutionContainmentRequest & { readonly authentication?: true; readonly allowance?: true; readonly structuredOutput?: true; readonly containment?: true; readonly interactive?: true };

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
  let request: CliRequest;
  try {
    request = parseArguments(arguments_);
  } catch {
    stderr.write(
      "Usage: node src/cli.ts [protocol-validate] [--path PATH] [--restart] | auth-validate --interactive [--path PATH] | allowance-validate [--path PATH] | containment-validate --job-id ID | structured-output-validate --job-id ID\n",
    );
    return 2;
  }

  const provider = dependencies.provider ?? new CodexAppServerAdapter({ openLoginUrl: openManagedBrowser });
  const result = request.containment
    ? provider.validatePreventiveExecutionContainment
      ? await provider.validatePreventiveExecutionContainment(request)
      : { ok: false as const, code: "containment_boundary_unavailable" as const, correlationId: "cli-containment-denied", stopCondition: "containment_boundary_unavailable", providerActionEnabled: false as const, canonicalStateOperationEnabled: false as const }
    : request.structuredOutput
    ? provider.validateStructuredOutput
      ? await provider.validateStructuredOutput(request)
      : { ok: false as const, code: "containment_attestation_required" as const, correlationId: "cli-structured-output-denied", stopCondition: "containment_attestation_required", providerActionEnabled: false as const, canonicalStateOperationEnabled: false as const }
    : request.authentication
    ? provider.validateAuthentication
      ? await provider.validateAuthentication(request)
      : { ok: false as const, code: "authentication_unsupported" as const, correlationId: "cli-auth-unsupported", remediation: { action: "inspect_local_evidence" as const }, providerActionEnabled: false as const, canonicalStateOperationEnabled: false as const }
    : request.allowance
      ? provider.validateAllowance
        ? await provider.validateAllowance(request)
        : { ok: false as const, code: "allowance_unsupported" as const, correlationId: "cli-allowance-unsupported", remediation: { action: "inspect_local_evidence" as const }, providerActionEnabled: false as const, canonicalStateOperationEnabled: false as const }
      : await provider.validateRuntime(request);
  stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  return result.ok ? 0 : 1;
}

export function parseArguments(arguments_: readonly string[]): CliRequest {
  const request: { path?: string; restart?: boolean; authentication?: true; allowance?: true; structuredOutput?: true; containment?: true; interactive?: true; jobId?: string } = {};
  let index = 0;
  if (arguments_[0] === "protocol-validate") index = 1;
  else if (arguments_[0] === "auth-validate") { request.authentication = true; index = 1; }
  else if (arguments_[0] === "allowance-validate") { request.allowance = true; index = 1; }
  else if (arguments_[0] === "containment-validate") { request.containment = true; index = 1; }
  else if (arguments_[0] === "structured-output-validate") { request.structuredOutput = true; index = 1; }
  else if (arguments_[0] && !arguments_[0].startsWith("--")) throw new Error("unknown command");
  while (index < arguments_.length) {
    const option = arguments_[index];
    if (option === "--restart") {
      if (request.authentication || request.allowance || request.structuredOutput || request.containment) throw new Error("restart unavailable for validation mode");
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
    if (option === "--interactive") {
      if (!request.authentication || request.interactive) throw new Error("interactive auth required once");
      request.interactive = true;
      index += 1;
      continue;
    }
    if (option === "--job-id") {
      const value = arguments_[index + 1];
      if ((!request.structuredOutput && !request.containment) || !value || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/u.test(value) || request.jobId) throw new Error("invalid job id");
      request.jobId = value; index += 2; continue;
    }
    throw new Error("unknown option");
  }
  if (request.authentication && !request.interactive) throw new Error("auth requires explicit interactive opt-in");
  if ((request.structuredOutput || request.containment) && !request.jobId) throw new Error("validation requires job id");
  return request as CliRequest;
}

async function openManagedBrowser(url: string): Promise<void> {
  if (process.platform !== "darwin") throw new Error("authentication_unsupported");
  await new Promise<void>((resolveOpen, rejectOpen) => {
    const child = spawn("open", [url], { stdio: "ignore", shell: false });
    child.once("error", rejectOpen);
    child.once("exit", (code) => code === 0 ? resolveOpen() : rejectOpen(new Error("authentication_failed")));
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
