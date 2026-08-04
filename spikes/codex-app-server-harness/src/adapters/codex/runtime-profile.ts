import { createHash } from "node:crypto";
import { homedir, tmpdir } from "node:os";
import { dirname, relative, resolve, sep } from "node:path";
import {
  chmod,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  realpath,
  stat,
  writeFile,
} from "node:fs/promises";

import type { CertificateConfiguration } from "../../core/ai-provider-port.ts";

const STRICT_CONFIG =
  'forced_login_method = "chatgpt"\n' +
  'cli_auth_credentials_store = "keyring"\n' +
  "[analytics]\n" +
  "enabled = false\n";

const DEFAULT_MINIMAL_PATH = `${dirname(process.execPath)}:/usr/bin:/bin:/usr/sbin:/sbin`;

export interface RuntimeProfileOptions {
  readonly baseDirectory?: string;
  readonly realHome?: string;
  readonly normalProfileRoot?: string;
  readonly parentEnvironment?: Readonly<Record<string, string | undefined>>;
  readonly minimalPath?: string;
  readonly certificateConfiguration?: CertificateConfiguration;
}

export interface IsolatedRuntimeProfile {
  readonly runtimeRoot: string;
  readonly codexHome: string;
  readonly codexSqliteHome: string;
  readonly disposableHome: string;
  readonly workingDirectory: string;
  readonly temporaryDirectory: string;
  readonly configPath: string;
  readonly strictConfigurationFingerprint: string;
  readonly childEnvironment: Readonly<Record<string, string>>;
  readonly allowedEnvironmentNames: readonly string[];
  readonly environmentFingerprints: Readonly<Record<string, string>>;
}

export interface FixtureFileSnapshot {
  readonly digest: string;
  readonly mode: number;
  readonly size: number;
  readonly modifiedAtMs: number;
}

export interface FixtureDirectorySnapshot {
  readonly mode: number;
  readonly modifiedAtMs: number;
}

export interface FixtureSnapshot {
  readonly directories: Readonly<Record<string, FixtureDirectorySnapshot>>;
  readonly files: Readonly<Record<string, FixtureFileSnapshot>>;
}

/** Metadata-only audit: credential contents are never opened or inspected. */
export async function auditProjectOSProfileCredentialOwnership(
  profile: IsolatedRuntimeProfile,
): Promise<"codex_keyring_only"> {
  const names = await collectRelativeNames(profile.runtimeRoot, profile.runtimeRoot);
  if (names.some((name) => !isExpectedProfileArtifact(name))) {
    throw isolationError();
  }
  // The forced config is written by us and is the only credential-storage assertion.
  const config = await readFile(profile.configPath, "utf8");
  if (config !== STRICT_CONFIG) throw isolationError();
  return "codex_keyring_only";
}

function isExpectedProfileArtifact(name: string): boolean {
  // The harness controls snapshots and generated schemas. Every file in the disposable
  // CODEX_HOME/HOME/SQLite/work/tmp roots is unexpected except this exact forced config.
  // This stays metadata-only: no credential file is opened to classify its contents.
  return name === "codex-home/config.toml" ||
    name.startsWith("executable-snapshot/") ||
    name.startsWith("protocol-generated/");
}

export async function createIsolatedRuntimeProfile(
  options: RuntimeProfileOptions = {},
): Promise<IsolatedRuntimeProfile> {
  void options.parentEnvironment;
  const requestedBase = options.baseDirectory ?? `${tmpdir()}/projectos-codex-harness`;
  const canonicalBase = await prepareBaseDirectory(requestedBase);
  const canonicalRealHome = await canonicalExistingPath(options.realHome ?? homedir());
  const canonicalNormalProfile = options.normalProfileRoot
    ? await canonicalExistingPath(options.normalProfileRoot)
    : undefined;

  if (
    isSameOrWithin(canonicalBase, canonicalRealHome) ||
    (canonicalNormalProfile !== undefined && isSameOrWithin(canonicalBase, canonicalNormalProfile))
  ) {
    throw isolationError();
  }

  const runtimeRoot = await mkdtemp(`${canonicalBase}/run-`);
  await chmod(runtimeRoot, 0o700);
  const codexHome = await createPrivateDirectory(runtimeRoot, "codex-home");
  const codexSqliteHome = await createPrivateDirectory(runtimeRoot, "codex-sqlite-home");
  const disposableHome = await createPrivateDirectory(runtimeRoot, "home");
  const workingDirectory = await createPrivateDirectory(runtimeRoot, "work");
  const temporaryDirectory = await createPrivateDirectory(runtimeRoot, "tmp");
  const configPath = `${codexHome}/config.toml`;
  await writeFile(configPath, STRICT_CONFIG, { encoding: "utf8", mode: 0o600, flag: "wx" });
  await chmod(configPath, 0o600);

  const childEnvironment: Record<string, string> = {
    HOME: disposableHome,
    CODEX_HOME: codexHome,
    CODEX_SQLITE_HOME: codexSqliteHome,
    TMPDIR: temporaryDirectory,
    LANG: "C.UTF-8",
    LC_ALL: "C.UTF-8",
    PATH: options.minimalPath ?? DEFAULT_MINIMAL_PATH,
  };
  if (options.certificateConfiguration?.nodeExtraCaCerts) {
    childEnvironment.NODE_EXTRA_CA_CERTS = options.certificateConfiguration.nodeExtraCaCerts;
  }
  if (options.certificateConfiguration?.sslCertFile) {
    childEnvironment.SSL_CERT_FILE = options.certificateConfiguration.sslCertFile;
  }

  const allowedEnvironmentNames = Object.keys(childEnvironment).sort();
  const environmentFingerprints = Object.fromEntries(
    allowedEnvironmentNames.map((name) => [name, sha256(`${name}\0${childEnvironment[name]}`)]),
  );

  return Object.freeze({
    runtimeRoot,
    codexHome,
    codexSqliteHome,
    disposableHome,
    workingDirectory,
    temporaryDirectory,
    configPath,
    strictConfigurationFingerprint: sha256(STRICT_CONFIG),
    childEnvironment: Object.freeze(childEnvironment),
    allowedEnvironmentNames: Object.freeze(allowedEnvironmentNames),
    environmentFingerprints: Object.freeze(environmentFingerprints),
  });
}

export async function createSyntheticNormalProfileFixture(path: string): Promise<string> {
  await mkdir(`${path}/sessions`, { recursive: true, mode: 0o700 });
  await chmod(path, 0o700);
  await chmod(`${path}/sessions`, 0o700);
  await Promise.all([
    writePrivateFixtureFile(`${path}/config.toml`, 'profile_marker = "synthetic-normal"\n'),
    writePrivateFixtureFile(`${path}/auth.json`, '{"synthetic":true}\n'),
    writePrivateFixtureFile(`${path}/sessions/sentinel.json`, '{"session":"synthetic"}\n'),
  ]);
  return realpath(path);
}

export async function snapshotFixture(root: string): Promise<FixtureSnapshot> {
  const canonicalRoot = await canonicalExistingPath(root);
  const { directories, files } = await collectFixtureEntries(canonicalRoot);
  const fileEntries = await Promise.all(
    files.map(async (path) => {
      const metadata = await stat(path);
      const relativePath = relative(canonicalRoot, path);
      return [
        relativePath,
        {
          digest: sha256(await readFile(path)),
          mode: metadata.mode & 0o777,
          size: metadata.size,
          modifiedAtMs: metadata.mtimeMs,
        },
      ] as const;
    }),
  );
  const directoryEntries = await Promise.all(
    directories.map(async (path) => {
      const metadata = await stat(path);
      return [
        relative(canonicalRoot, path),
        {
          mode: metadata.mode & 0o777,
          modifiedAtMs: metadata.mtimeMs,
        },
      ] as const;
    }),
  );
  return Object.freeze({
    directories: Object.freeze(Object.fromEntries(directoryEntries)),
    files: Object.freeze(Object.fromEntries(fileEntries)),
  });
}

export async function assertFixtureUnchanged(
  before: FixtureSnapshot,
  after: FixtureSnapshot,
): Promise<void> {
  if (JSON.stringify(before) !== JSON.stringify(after)) throw isolationError();
}

async function prepareBaseDirectory(path: string): Promise<string> {
  try {
    const metadata = await lstat(path);
    if (metadata.isSymbolicLink() || !metadata.isDirectory()) throw isolationError();
  } catch (error: unknown) {
    if (!isMissing(error)) throw error;
    await mkdir(path, { recursive: true, mode: 0o700 });
  }
  const canonical = await realpath(path);
  await chmod(canonical, 0o700);
  return canonical;
}

async function canonicalExistingPath(path: string): Promise<string> {
  return realpath(path);
}

async function createPrivateDirectory(parent: string, name: string): Promise<string> {
  const path = `${parent}/${name}`;
  await mkdir(path, { mode: 0o700 });
  await chmod(path, 0o700);
  const canonical = await realpath(path);
  if (dirname(canonical) !== parent) throw isolationError();
  return canonical;
}

async function writePrivateFixtureFile(path: string, contents: string): Promise<void> {
  await writeFile(path, contents, { encoding: "utf8", mode: 0o600, flag: "wx" });
  await chmod(path, 0o600);
}

async function collectFixtureEntries(
  root: string,
): Promise<{ readonly directories: string[]; readonly files: string[] }> {
  const directories = [root];
  const files: string[] = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = `${root}/${entry.name}`;
    if (entry.isSymbolicLink()) throw isolationError();
    if (entry.isDirectory()) {
      const nested = await collectFixtureEntries(path);
      directories.push(...nested.directories);
      files.push(...nested.files);
    }
    else if (entry.isFile()) files.push(path);
    else throw isolationError();
  }
  return { directories: directories.sort(), files: files.sort() };
}

async function collectRelativeNames(root: string, directory: string): Promise<readonly string[]> {
  const names: string[] = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isSymbolicLink()) throw isolationError();
    if (entry.isDirectory()) names.push(...await collectRelativeNames(root, path));
    else if (entry.isFile()) names.push(relative(root, path));
    else throw isolationError();
  }
  return names;
}

function isSameOrWithin(candidate: string, parent: string): boolean {
  const fromParent = relative(resolve(parent), resolve(candidate));
  return fromParent === "" || (!fromParent.startsWith(`..${sep}`) && fromParent !== "..");
}

function sha256(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

function isolationError(): Error {
  return new Error("isolation_failed");
}

function isMissing(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}
