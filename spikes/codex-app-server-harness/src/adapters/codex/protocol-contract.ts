import { createHash } from "node:crypto";
import { lstat, readFile, readdir } from "node:fs/promises";
import { join, posix, relative, resolve } from "node:path";

export const PROTOCOL_MANIFEST_FORMAT_VERSION = 1 as const;
export const PROTOCOL_DIGEST_ALGORITHM = "projectos-schema-tree-sha256-v1" as const;

export const DEFAULT_PROTOCOL_LIMITS = Object.freeze({
  maximumFiles: 1_024,
  maximumFileBytes: 16 * 1024 * 1024,
  maximumBundleBytes: 64 * 1024 * 1024,
  maximumDepth: 32,
});

export interface ProtocolSchemaDigestFile {
  readonly path: string;
  readonly sha256: string;
}

export interface ProtocolSchemaBundle {
  readonly algorithm: typeof PROTOCOL_DIGEST_ALGORITHM;
  readonly files: readonly ProtocolSchemaDigestFile[];
  readonly aggregateSha256: string;
}

export interface ProtocolMethodSets {
  readonly clientRequests: readonly string[];
  readonly clientNotifications: readonly string[];
  readonly serverNotifications: readonly string[];
  readonly serverRequests: readonly string[];
}

export type InboundMethodClassification = "semantic_notification" | "forbidden" | "unknown";

export interface ProtocolBoundary {
  readonly enabledClientRequests: readonly string[];
  readonly enabledClientNotifications: readonly string[];
  assertClientRequest(method: string): void;
  assertClientNotification(method: string): void;
  classifyInbound(
    method: string,
    direction: "server_notification" | "server_request",
  ): InboundMethodClassification;
}

export interface AuthenticationProtocolContract {
  readonly clientRequests: readonly [
    "account/login/cancel", "account/login/start", "account/logout", "account/read",
  ];
  readonly serverNotifications: readonly ["account/login/completed", "account/updated"];
}

export interface AllowanceProtocolContract {
  readonly clientRequests: readonly ["account/rateLimits/read"];
  readonly serverNotifications: readonly ["account/rateLimits/updated"];
}

export interface SupportedRuntimeManifest {
  readonly formatVersion: typeof PROTOCOL_MANIFEST_FORMAT_VERSION;
  readonly manifestId: string;
  readonly runtime: {
    readonly build: string;
    readonly platform: string;
    readonly architecture: string;
    readonly binaryContentSha256: string;
  };
  readonly generation: {
    readonly jsonArgv: readonly ["app-server", "generate-json-schema", "--out", "$JSON_OUT"];
    readonly typescriptArgv: readonly ["app-server", "generate-ts", "--out", "$TS_OUT"];
    readonly digestAlgorithm: typeof PROTOCOL_DIGEST_ALGORITHM;
  };
  readonly schemas: {
    readonly json: ProtocolSchemaBundle;
    readonly typescript: ProtocolSchemaBundle;
  };
  readonly requiredMethods: ProtocolMethodSets & {
    readonly recognizedForbidden: readonly string[];
  };
  readonly enabledDispatch: {
    readonly clientRequests: readonly string[];
    readonly clientNotifications: readonly string[];
  };
  readonly authentication?: AuthenticationProtocolContract;
  readonly allowance?: AllowanceProtocolContract;
}

export interface CollectProtocolSchemaBundleOptions {
  readonly maximumFiles?: number;
  readonly maximumFileBytes?: number;
  readonly maximumBundleBytes?: number;
  readonly maximumDepth?: number;
}

export interface CompatibilityComparisonInput {
  readonly manifest: SupportedRuntimeManifest;
  readonly detectedBuild: string;
  readonly detectedPlatform: string;
  readonly detectedArchitecture: string;
  readonly binaryContentSha256: string;
  readonly jsonBundle: ProtocolSchemaBundle;
  readonly typescriptBundle: ProtocolSchemaBundle;
  readonly detectedMethods?: ProtocolMethodSets;
}

export type CompatibilityMismatch =
  | "unsupported_build"
  | "unsupported_platform"
  | "unsupported_architecture"
  | "binary_mismatch"
  | "schema_mismatch"
  | "missing_required_method"
  | "unsupported_dispatch";

export type CompatibilityComparison =
  | { readonly ok: true; readonly input: CompatibilityComparisonInput }
  | {
      readonly ok: false;
      readonly mismatch: CompatibilityMismatch;
      readonly input: CompatibilityComparisonInput;
    };

export async function collectProtocolSchemaBundle(
  root: string,
  kind: "json" | "typescript",
  options: CollectProtocolSchemaBundleOptions = {},
): Promise<ProtocolSchemaBundle> {
  const limits = {
    maximumFiles: options.maximumFiles ?? DEFAULT_PROTOCOL_LIMITS.maximumFiles,
    maximumFileBytes: options.maximumFileBytes ?? DEFAULT_PROTOCOL_LIMITS.maximumFileBytes,
    maximumBundleBytes: options.maximumBundleBytes ?? DEFAULT_PROTOCOL_LIMITS.maximumBundleBytes,
    maximumDepth: options.maximumDepth ?? DEFAULT_PROTOCOL_LIMITS.maximumDepth,
  };
  assertValidLimits(limits);
  const canonicalRoot = resolve(root);
  let rootMetadata: Awaited<ReturnType<typeof lstat>>;
  try {
    rootMetadata = await lstat(canonicalRoot);
  } catch {
    throw invalidManifest();
  }
  if (!rootMetadata.isDirectory() || rootMetadata.isSymbolicLink()) throw invalidManifest();

  const paths = await collectRegularFiles(
    canonicalRoot,
    canonicalRoot,
    limits.maximumFiles,
    limits.maximumDepth,
  );
  if (paths.length === 0 || paths.length > limits.maximumFiles) throw invalidManifest();
  const files: ProtocolSchemaDigestFile[] = [];
  let bundleBytes = 0;
  for (const absolutePath of paths) {
    const relativePath = normalizeRelativePath(relative(canonicalRoot, absolutePath));
    const contents = await readFile(absolutePath);
    if (contents.length > limits.maximumFileBytes) throw invalidManifest();
    bundleBytes += contents.length;
    if (bundleBytes > limits.maximumBundleBytes) throw invalidManifest();
    let digestBytes = contents;
    if (kind === "json") {
      try {
        digestBytes = Buffer.from(JSON.stringify(canonicalizeJson(JSON.parse(contents.toString("utf8")))), "utf8");
      } catch {
        throw invalidManifest();
      }
    }
    files.push(Object.freeze({ path: relativePath, sha256: sha256(digestBytes) }));
  }
  files.sort((left, right) => codePointCompare(left.path, right.path));
  assertUniqueSortedFiles(files);
  return freezeBundle(files);
}

export async function extractGeneratedProtocolMethods(
  jsonSchemaRoot: string,
): Promise<ProtocolMethodSets> {
  const [clientRequests, clientNotifications, serverNotifications, serverRequests] =
    await Promise.all([
      extractMethodsFromSchema(join(jsonSchemaRoot, "ClientRequest.json")),
      extractMethodsFromSchema(join(jsonSchemaRoot, "ClientNotification.json")),
      extractMethodsFromSchema(join(jsonSchemaRoot, "ServerNotification.json")),
      extractMethodsFromSchema(join(jsonSchemaRoot, "ServerRequest.json")),
    ]);
  return Object.freeze({
    clientRequests,
    clientNotifications,
    serverNotifications,
    serverRequests,
  });
}

/**
 * This is intentionally conservative. The caller invokes it only after the exact
 * generated JSON bundle has matched the pinned manifest, so a true result proves
 * that the pinned `account/login/start` schema itself contains this safe branch.
 */
export async function generatedLoginSchemaSupportsDeviceCodeRecovery(
  jsonSchemaRoot: string,
): Promise<boolean> {
  try {
    const schema = JSON.parse(await readFile(join(jsonSchemaRoot, "ClientRequest.json"), "utf8"));
    return containsDeviceCodeLoginBranch(schema);
  } catch {
    return false;
  }
}

export function parseSupportedRuntimeManifest(serialized: string): SupportedRuntimeManifest {
  let value: unknown;
  try {
    value = JSON.parse(serialized);
  } catch {
    throw invalidManifest();
  }
  if (
    !(hasExactKeys(value, [
      "allowance", "authentication",
      "enabledDispatch",
      "formatVersion",
      "generation",
      "manifestId",
      "requiredMethods",
      "runtime",
      "schemas",
    ]) || hasExactKeys(value, [
      "enabledDispatch", "formatVersion", "generation", "manifestId", "requiredMethods", "runtime", "schemas",
    ])) ||
    value.formatVersion !== PROTOCOL_MANIFEST_FORMAT_VERSION
  ) {
    throw invalidManifest();
  }
  const manifest = value as unknown as SupportedRuntimeManifest;
  if (
    !safeIdentifier(manifest.manifestId) ||
    !hasExactKeys(manifest.runtime, [
      "architecture",
      "binaryContentSha256",
      "build",
      "platform",
    ]) ||
    !isSafeRuntimeBuild(manifest.runtime.build) ||
    !safeIdentifier(manifest.runtime.platform) ||
    !safeIdentifier(manifest.runtime.architecture) ||
    !isSha256(manifest.runtime.binaryContentSha256) ||
    !hasExactKeys(manifest.generation, ["digestAlgorithm", "jsonArgv", "typescriptArgv"]) ||
    !exactArray(manifest.generation.jsonArgv, [
      "app-server",
      "generate-json-schema",
      "--out",
      "$JSON_OUT",
    ]) ||
    !exactArray(manifest.generation.typescriptArgv, [
      "app-server",
      "generate-ts",
      "--out",
      "$TS_OUT",
    ]) ||
    manifest.generation.digestAlgorithm !== PROTOCOL_DIGEST_ALGORITHM ||
    !hasExactKeys(manifest.schemas, ["json", "typescript"]) ||
    !validBundle(manifest.schemas.json) ||
    !validBundle(manifest.schemas.typescript) ||
    !hasExactKeys(manifest.requiredMethods, [
      "clientNotifications",
      "clientRequests",
      "recognizedForbidden",
      "serverNotifications",
      "serverRequests",
    ]) ||
    !validMethodSets(manifest.requiredMethods) ||
    !validSortedStrings(manifest.requiredMethods.recognizedForbidden) ||
    !hasExactKeys(manifest.enabledDispatch, ["clientNotifications", "clientRequests"]) ||
    !validSortedStrings(manifest.enabledDispatch.clientRequests) ||
    !validSortedStrings(manifest.enabledDispatch.clientNotifications) ||
    (manifest.authentication !== undefined && !validAuthenticationContract(manifest.authentication)) ||
    (manifest.allowance !== undefined && !validAllowanceContract(manifest.allowance))
  ) {
    throw invalidManifest();
  }
  if (
    !isSubset(manifest.enabledDispatch.clientRequests, manifest.requiredMethods.clientRequests) ||
    !isSubset(
      manifest.enabledDispatch.clientNotifications,
      manifest.requiredMethods.clientNotifications,
    ) ||
    !exactArray(manifest.enabledDispatch.clientRequests, ["initialize"]) ||
    !exactArray(manifest.enabledDispatch.clientNotifications, ["initialized"]) ||
    !isSubset(manifest.requiredMethods.serverRequests, manifest.requiredMethods.recognizedForbidden) ||
    manifest.requiredMethods.serverNotifications.some((method) =>
      manifest.requiredMethods.recognizedForbidden.includes(method),
    )
  ) {
    throw invalidManifest();
  }
  return deepFreezeManifest(manifest);
}

export function compareSupportedProtocol(
  input: CompatibilityComparisonInput,
): CompatibilityComparison {
  const fail = (mismatch: CompatibilityMismatch): CompatibilityComparison =>
    Object.freeze({ ok: false, mismatch, input });
  if (input.detectedBuild !== input.manifest.runtime.build) return fail("unsupported_build");
  if (input.detectedPlatform !== input.manifest.runtime.platform) {
    return fail("unsupported_platform");
  }
  if (input.detectedArchitecture !== input.manifest.runtime.architecture) {
    return fail("unsupported_architecture");
  }
  if (input.binaryContentSha256 !== input.manifest.runtime.binaryContentSha256) {
    return fail("binary_mismatch");
  }
  if (
    !sameBundle(input.jsonBundle, input.manifest.schemas.json) ||
    !sameBundle(input.typescriptBundle, input.manifest.schemas.typescript)
  ) {
    return fail("schema_mismatch");
  }
  if (
    input.detectedMethods &&
    (!containsRequiredMethods(input.detectedMethods, input.manifest.requiredMethods) ||
      !hasPinnedForbiddenDirections(
        input.detectedMethods,
        input.manifest.requiredMethods.recognizedForbidden,
      ))
  ) {
    return fail("missing_required_method");
  }
  if (
    !exactArray(input.manifest.enabledDispatch.clientRequests, ["initialize"]) ||
    !exactArray(input.manifest.enabledDispatch.clientNotifications, ["initialized"])
  ) {
    return fail("unsupported_dispatch");
  }
  return Object.freeze({ ok: true, input });
}

export function createProtocolBoundary(
  manifest: SupportedRuntimeManifest,
  detectedMethods: ProtocolMethodSets,
): ProtocolBoundary {
  if (
    !exactArray(manifest.enabledDispatch.clientRequests, ["initialize"]) ||
    !exactArray(manifest.enabledDispatch.clientNotifications, ["initialized"])
  ) {
    throw new Error("unsupported_dispatch");
  }
  const requests = new Set(manifest.enabledDispatch.clientRequests);
  const notifications = new Set(manifest.enabledDispatch.clientNotifications);
  const semanticNotifications = new Set(manifest.requiredMethods.serverNotifications);
  if (!hasPinnedForbiddenDirections(detectedMethods, manifest.requiredMethods.recognizedForbidden)) {
    throw new Error("missing_required_method");
  }
  const forbidden = new Set(manifest.requiredMethods.recognizedForbidden);
  const forbiddenNotifications = new Set(
    detectedMethods.serverNotifications.filter((method) => forbidden.has(method)),
  );
  const forbiddenRequests = new Set(
    detectedMethods.serverRequests.filter((method) => forbidden.has(method)),
  );
  return Object.freeze({
    enabledClientRequests: Object.freeze([...requests].sort(codePointCompare)),
    enabledClientNotifications: Object.freeze([...notifications].sort(codePointCompare)),
    assertClientRequest(method: string): void {
      if (!requests.has(method)) throw new Error("unsupported_dispatch");
    },
    assertClientNotification(method: string): void {
      if (!notifications.has(method)) throw new Error("unsupported_dispatch");
    },
    classifyInbound(
      method: string,
      direction: "server_notification" | "server_request",
    ): InboundMethodClassification {
      if (direction === "server_request") {
        return forbiddenRequests.has(method) ? "forbidden" : "unknown";
      }
      if (forbiddenNotifications.has(method)) return "forbidden";
      if (semanticNotifications.has(method)) return "semantic_notification";
      return "unknown";
    },
  });
}

/** Authentication is opt-in; the default protocol boundary remains init-only. */
export function createAuthenticationProtocolBoundary(
  manifest: SupportedRuntimeManifest,
  detectedMethods: ProtocolMethodSets,
): ProtocolBoundary {
  const auth = manifest.authentication;
  if (!auth || !isSubset(auth.clientRequests, detectedMethods.clientRequests) ||
      !isSubset(auth.serverNotifications, detectedMethods.serverNotifications)) {
    throw new Error("authentication_unsupported");
  }
  const requests = new Set<string>(["initialize", ...auth.clientRequests]);
  const notifications = new Set<string>(["initialized"]);
  const semantic = new Set<string>(auth.serverNotifications);
  const forbidden = new Set(manifest.requiredMethods.recognizedForbidden);
  return Object.freeze({
    enabledClientRequests: Object.freeze([...requests].sort(codePointCompare)),
    enabledClientNotifications: Object.freeze([...notifications]),
    assertClientRequest(method: string): void { if (!requests.has(method)) throw new Error("unsupported_dispatch"); },
    assertClientNotification(method: string): void { if (!notifications.has(method)) throw new Error("unsupported_dispatch"); },
    classifyInbound(method: string, direction: "server_notification" | "server_request"): InboundMethodClassification {
      if (direction === "server_request") return forbidden.has(method) ? "forbidden" : "unknown";
      if (forbidden.has(method)) return "forbidden";
      return semantic.has(method) ? "semantic_notification" : "unknown";
    },
  });
}

/** Allowance is a separate, read-only mode. It never inherits auth or turn dispatch. */
export function createAllowanceProtocolBoundary(
  manifest: SupportedRuntimeManifest,
  detectedMethods: ProtocolMethodSets,
): ProtocolBoundary {
  const allowance = manifest.allowance;
  if (!allowance || !isSubset(allowance.clientRequests, detectedMethods.clientRequests) ||
      !isSubset(allowance.serverNotifications, detectedMethods.serverNotifications)) {
    throw new Error("allowance_unsupported");
  }
  const requests = new Set<string>(["initialize", ...allowance.clientRequests]);
  const notifications = new Set<string>(["initialized"]);
  const semantic = new Set<string>(allowance.serverNotifications);
  const forbidden = new Set(manifest.requiredMethods.recognizedForbidden);
  return Object.freeze({
    enabledClientRequests: Object.freeze([...requests].sort(codePointCompare)),
    enabledClientNotifications: Object.freeze([...notifications]),
    assertClientRequest(method: string): void { if (!requests.has(method)) throw new Error("unsupported_dispatch"); },
    assertClientNotification(method: string): void { if (!notifications.has(method)) throw new Error("unsupported_dispatch"); },
    classifyInbound(method: string, direction: "server_notification" | "server_request"): InboundMethodClassification {
      if (direction === "server_request") return forbidden.has(method) ? "forbidden" : "unknown";
      if (forbidden.has(method)) return "forbidden";
      return semantic.has(method) ? "semantic_notification" : "unknown";
    },
  });
}

export function schemaTreeAggregateBytes(files: readonly ProtocolSchemaDigestFile[]): Buffer {
  return Buffer.from(
    JSON.stringify({ algorithm: PROTOCOL_DIGEST_ALGORITHM, files }),
    "utf8",
  );
}

export function sha256(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

async function collectRegularFiles(
  root: string,
  directory: string,
  maximumFiles: number,
  maximumDepth: number,
  depth = 0,
  state: { files: string[]; directories: number } = { files: [], directories: 1 },
): Promise<string[]> {
  if (depth > maximumDepth || state.directories > maximumFiles) throw invalidManifest();
  const collected: string[] = [];
  const entries = await readdir(directory, { withFileTypes: true });
  entries.sort((left, right) => codePointCompare(left.name, right.name));
  for (const entry of entries) {
    if (/[\u0000-\u001f\u007f\\]/u.test(entry.name) || entry.name === "." || entry.name === "..") {
      throw invalidManifest();
    }
    const path = resolve(directory, entry.name);
    if (!path.startsWith(`${root}/`)) throw invalidManifest();
    const metadata = await lstat(path);
    if (metadata.isSymbolicLink()) throw invalidManifest();
    if (metadata.isDirectory()) {
      state.directories += 1;
      if (state.directories > maximumFiles || depth >= maximumDepth) throw invalidManifest();
      collected.push(...(await collectRegularFiles(
        root,
        path,
        maximumFiles,
        maximumDepth,
        depth + 1,
        state,
      )));
    } else if (metadata.isFile()) {
      state.files.push(path);
      if (state.files.length > maximumFiles) throw invalidManifest();
      collected.push(path);
    }
    else throw invalidManifest();
  }
  return collected;
}

function normalizeRelativePath(path: string): string {
  if (
    !path ||
    path.startsWith("/") ||
    path.includes("\\") ||
    /[\u0000-\u001f\u007f]/u.test(path) ||
    path.split("/").some((segment) => segment === "" || segment === "." || segment === "..") ||
    posix.normalize(path) !== path
  ) {
    throw invalidManifest();
  }
  return path;
}

function freezeBundle(files: readonly ProtocolSchemaDigestFile[]): ProtocolSchemaBundle {
  const frozenFiles = Object.freeze(files.map((file) => Object.freeze({ ...file })));
  return Object.freeze({
    algorithm: PROTOCOL_DIGEST_ALGORITHM,
    files: frozenFiles,
    aggregateSha256: sha256(schemaTreeAggregateBytes(frozenFiles)),
  });
}

async function extractMethodsFromSchema(path: string): Promise<readonly string[]> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(await readFile(path, "utf8"));
  } catch {
    throw invalidManifest();
  }
  if (!isObject(parsed) || !Array.isArray(parsed.oneOf)) throw invalidManifest();
  const methods: string[] = [];
  for (const variant of parsed.oneOf) {
    if (!isObject(variant) || !isObject(variant.properties)) throw invalidManifest();
    const method = variant.properties.method;
    if (!isObject(method)) {
      throw invalidManifest();
    }
    const name = Array.isArray(method.enum) && method.enum.length === 1
      ? method.enum[0]
      : method.const;
    if (!safeMethod(name)) throw invalidManifest();
    methods.push(name);
  }
  methods.sort(codePointCompare);
  if (!validSortedStrings(methods) || methods.length === 0) throw invalidManifest();
  return Object.freeze(methods);
}

function validBundle(value: unknown): value is ProtocolSchemaBundle {
  if (
    !hasExactKeys(value, ["aggregateSha256", "algorithm", "files"]) ||
    value.algorithm !== PROTOCOL_DIGEST_ALGORITHM ||
    !Array.isArray(value.files) ||
    value.files.length < 1 ||
    value.files.length > DEFAULT_PROTOCOL_LIMITS.maximumFiles
  ) {
    return false;
  }
  const files: ProtocolSchemaDigestFile[] = [];
  for (const entry of value.files) {
    if (
      !hasExactKeys(entry, ["path", "sha256"]) ||
      typeof entry.path !== "string" ||
      !isSha256(entry.sha256)
    ) {
      return false;
    }
    try {
      files.push({ path: normalizeRelativePath(entry.path), sha256: entry.sha256 });
    } catch {
      return false;
    }
  }
  try {
    assertUniqueSortedFiles(files);
  } catch {
    return false;
  }
  return isSha256(value.aggregateSha256) &&
    value.aggregateSha256 === sha256(schemaTreeAggregateBytes(files));
}

function assertUniqueSortedFiles(files: readonly ProtocolSchemaDigestFile[]): void {
  let previous: string | undefined;
  for (const file of files) {
    normalizeRelativePath(file.path);
    if (!isSha256(file.sha256) || (previous !== undefined && codePointCompare(previous, file.path) >= 0)) {
      throw invalidManifest();
    }
    previous = file.path;
  }
}

function validMethodSets(value: unknown): value is ProtocolMethodSets {
  if (!isObject(value)) return false;
  return (
    validSortedStrings(value.clientRequests) &&
    validSortedStrings(value.clientNotifications) &&
    validSortedStrings(value.serverNotifications) &&
    validSortedStrings(value.serverRequests)
  );
}

function validAuthenticationContract(value: unknown): value is AuthenticationProtocolContract {
  return isObject(value) && hasExactKeys(value, ["clientRequests", "serverNotifications"]) &&
    exactArray(value.clientRequests, ["account/login/cancel", "account/login/start", "account/logout", "account/read"]) &&
    exactArray(value.serverNotifications, ["account/login/completed", "account/updated"]);
}

function validAllowanceContract(value: unknown): value is AllowanceProtocolContract {
  return isObject(value) && hasExactKeys(value, ["clientRequests", "serverNotifications"]) &&
    exactArray(value.clientRequests, ["account/rateLimits/read"]) &&
    exactArray(value.serverNotifications, ["account/rateLimits/updated"]);
}

function containsDeviceCodeLoginBranch(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(containsDeviceCodeLoginBranch);
  if (!isObject(value)) return false;
  const properties = isObject(value.properties) ? value.properties : undefined;
  if (
    properties !== undefined &&
    schemaPermitsLiteral(properties.method, "account/login/start") &&
    isObject(properties.params) &&
    isObject(properties.params.properties) &&
    schemaPermitsLiteral(properties.params.properties.type, "device_code")
  ) {
    return true;
  }
  return Object.values(value).some(containsDeviceCodeLoginBranch);
}

function schemaPermitsLiteral(value: unknown, literal: string): boolean {
  return isObject(value) &&
    (value.const === literal || (Array.isArray(value.enum) && value.enum.includes(literal)));
}

function validSortedStrings(value: unknown): value is readonly string[] {
  if (!Array.isArray(value)) return false;
  let previous: string | undefined;
  for (const item of value) {
    if (!safeMethod(item) || (previous !== undefined && codePointCompare(previous, item) >= 0)) return false;
    previous = item;
  }
  return true;
}

function containsRequiredMethods(detected: ProtocolMethodSets, required: ProtocolMethodSets): boolean {
  return (
    isSubset(required.clientRequests, detected.clientRequests) &&
    isSubset(required.clientNotifications, detected.clientNotifications) &&
    isSubset(required.serverNotifications, detected.serverNotifications) &&
    isSubset(required.serverRequests, detected.serverRequests)
  );
}

function hasPinnedForbiddenDirections(
  detected: ProtocolMethodSets,
  forbiddenMethods: readonly string[],
): boolean {
  const clientRequests = new Set(detected.clientRequests);
  const clientNotifications = new Set(detected.clientNotifications);
  const serverNotifications = new Set(detected.serverNotifications);
  const serverRequests = new Set(detected.serverRequests);
  return forbiddenMethods.every((method) => {
    const inboundDirectionCount = Number(serverNotifications.has(method)) + Number(serverRequests.has(method));
    return inboundDirectionCount === 1 &&
      !clientRequests.has(method) &&
      !clientNotifications.has(method);
  });
}

function assertValidLimits(limits: {
  readonly maximumFiles: number;
  readonly maximumFileBytes: number;
  readonly maximumBundleBytes: number;
  readonly maximumDepth: number;
}): void {
  if (
    !Number.isSafeInteger(limits.maximumFiles) ||
    !Number.isSafeInteger(limits.maximumFileBytes) ||
    !Number.isSafeInteger(limits.maximumBundleBytes) ||
    !Number.isSafeInteger(limits.maximumDepth) ||
    limits.maximumFiles < 1 ||
    limits.maximumFileBytes < 1 ||
    limits.maximumBundleBytes < 1 ||
    limits.maximumDepth < 1
  ) {
    throw invalidManifest();
  }
}

function isSubset(subset: readonly string[], superset: readonly string[]): boolean {
  const values = new Set(superset);
  return subset.every((value) => values.has(value));
}

function sameBundle(left: ProtocolSchemaBundle, right: ProtocolSchemaBundle): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function exactArray(value: unknown, expected: readonly string[]): boolean {
  return Array.isArray(value) &&
    value.length === expected.length &&
    value.every((item, index) => item === expected[index]);
}

function safeIdentifier(value: unknown): value is string {
  return typeof value === "string" && /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/u.test(value);
}

export function isSafeRuntimeBuild(value: unknown): value is string {
  return typeof value === "string" &&
    /^codex(?:-cli)?\s+[a-zA-Z0-9][a-zA-Z0-9._+-]{0,127}$/u.test(value);
}

function safeMethod(value: unknown): value is string {
  return typeof value === "string" && /^[a-zA-Z][a-zA-Z0-9._/-]{0,255}$/u.test(value);
}

function isSha256(value: unknown): value is string {
  return typeof value === "string" && /^[a-f0-9]{64}$/u.test(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: unknown,
  expectedKeys: readonly string[],
): value is Record<string, unknown> {
  if (!isObject(value)) return false;
  const actualKeys = Object.keys(value).sort(codePointCompare);
  const sortedExpectedKeys = [...expectedKeys].sort(codePointCompare);
  return exactArray(actualKeys, sortedExpectedKeys);
}

function codePointCompare(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

function canonicalizeJson(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalizeJson);
  if (isObject(value)) {
    return Object.fromEntries(
      Object.keys(value)
        .sort(codePointCompare)
        .map((key) => [key, canonicalizeJson(value[key])]),
    );
  }
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return value;
  }
  throw invalidManifest();
}

function deepFreezeManifest(manifest: SupportedRuntimeManifest): SupportedRuntimeManifest {
  return Object.freeze({
    ...manifest,
    runtime: Object.freeze({ ...manifest.runtime }),
    generation: Object.freeze({ ...manifest.generation }),
    schemas: Object.freeze({
      json: freezeBundle(manifest.schemas.json.files),
      typescript: freezeBundle(manifest.schemas.typescript.files),
    }),
    requiredMethods: Object.freeze({
      clientRequests: Object.freeze([...manifest.requiredMethods.clientRequests]),
      clientNotifications: Object.freeze([...manifest.requiredMethods.clientNotifications]),
      serverNotifications: Object.freeze([...manifest.requiredMethods.serverNotifications]),
      serverRequests: Object.freeze([...manifest.requiredMethods.serverRequests]),
      recognizedForbidden: Object.freeze([...manifest.requiredMethods.recognizedForbidden]),
    }),
    enabledDispatch: Object.freeze({
      clientRequests: Object.freeze([...manifest.enabledDispatch.clientRequests]),
      clientNotifications: Object.freeze([...manifest.enabledDispatch.clientNotifications]),
    }),
    ...(manifest.authentication ? {
      authentication: Object.freeze({
        clientRequests: Object.freeze([...manifest.authentication.clientRequests]) as AuthenticationProtocolContract["clientRequests"],
        serverNotifications: Object.freeze([...manifest.authentication.serverNotifications]) as AuthenticationProtocolContract["serverNotifications"],
      }),
    } : {}),
    ...(manifest.allowance ? {
      allowance: Object.freeze({
        clientRequests: Object.freeze([...manifest.allowance.clientRequests]) as AllowanceProtocolContract["clientRequests"],
        serverNotifications: Object.freeze([...manifest.allowance.serverNotifications]) as AllowanceProtocolContract["serverNotifications"],
      }),
    } : {}),
  });
}

function invalidManifest(): Error {
  return new Error("invalid_manifest");
}
