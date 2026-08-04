import { createHash } from "node:crypto";
import { constants } from "node:fs";
import { chmod, lstat, mkdir, open, rm, stat } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";

export const DEFAULT_MAXIMUM_RUNTIME_SNAPSHOT_BYTES = 512 * 1024 * 1024;
const COPY_BUFFER_BYTES = 1024 * 1024;
const executableSnapshotBrand: unique symbol = Symbol("projectos.executable-snapshot");

export interface ExecutableSnapshotOptions {
  readonly sourcePath: string;
  readonly instanceDirectory: string;
  readonly maximumBytes?: number;
  readonly afterSourceOpened?: () => void | Promise<void>;
}

export type ExecutableSnapshot = Readonly<{
  readonly [executableSnapshotBrand]: true;
  readonly snapshotDirectory: string;
  readonly executablePath: string;
  readonly binaryContentSha256: string;
  readonly byteLength: number;
}>;

export interface OwnedExecutableSnapshotFacts {
  readonly executablePath: string;
  readonly binaryContentSha256: string;
  readonly byteLength: number;
}

const ownedExecutableSnapshotFacts = new WeakMap<object, OwnedExecutableSnapshotFacts>();

export class RuntimeSnapshotError extends Error {
  constructor() {
    super("runtime_snapshot_failed");
    this.name = "RuntimeSnapshotError";
  }
}

export async function createExecutableSnapshot(
  options: ExecutableSnapshotOptions,
): Promise<ExecutableSnapshot> {
  const instanceDirectory = resolve(options.instanceDirectory);
  const sourcePath = resolve(options.sourcePath);
  const maximumBytes = options.maximumBytes ?? DEFAULT_MAXIMUM_RUNTIME_SNAPSHOT_BYTES;
  const snapshotDirectory = join(instanceDirectory, "executable-snapshot");
  const executablePath = join(snapshotDirectory, basename(sourcePath));
  let source: Awaited<ReturnType<typeof open>> | undefined;
  let destination: Awaited<ReturnType<typeof open>> | undefined;
  let created = false;

  try {
    const instanceMetadata = await lstat(instanceDirectory);
    const sourceMetadata = await lstat(sourcePath);
    if (
      instanceMetadata.isSymbolicLink() ||
      !instanceMetadata.isDirectory() ||
      sourceMetadata.isSymbolicLink() ||
      !sourceMetadata.isFile() ||
      sourceMetadata.size <= 0 ||
      sourceMetadata.size > maximumBytes ||
      (sourceMetadata.mode & 0o111) === 0 ||
      dirname(snapshotDirectory) !== instanceDirectory
    ) {
      throw new RuntimeSnapshotError();
    }

    source = await open(sourcePath, constants.O_RDONLY | constants.O_NOFOLLOW);
    const before = await source.stat();
    if (!before.isFile() || before.size <= 0 || before.size > maximumBytes) {
      throw new RuntimeSnapshotError();
    }
    await options.afterSourceOpened?.();

    await mkdir(snapshotDirectory, { mode: 0o700 });
    created = true;
    await chmod(snapshotDirectory, 0o700);
    destination = await open(executablePath, "wx", 0o500);
    const hash = createHash("sha256");
    const buffer = Buffer.allocUnsafe(Math.min(COPY_BUFFER_BYTES, before.size));
    let copied = 0;
    while (copied < before.size) {
      const remaining = before.size - copied;
      const { bytesRead } = await source.read(buffer, 0, Math.min(buffer.length, remaining), null);
      if (bytesRead <= 0) throw new RuntimeSnapshotError();
      hash.update(buffer.subarray(0, bytesRead));
      let written = 0;
      while (written < bytesRead) {
        const result = await destination.write(buffer, written, bytesRead - written, null);
        if (result.bytesWritten <= 0) throw new RuntimeSnapshotError();
        written += result.bytesWritten;
      }
      copied += bytesRead;
    }
    const unexpected = Buffer.allocUnsafe(1);
    if ((await source.read(unexpected, 0, 1, null)).bytesRead !== 0) throw new RuntimeSnapshotError();

    const after = await source.stat();
    if (!sameOpenFile(before, after) || copied !== before.size) throw new RuntimeSnapshotError();
    await destination.sync();
    await destination.close();
    destination = undefined;
    await source.close();
    source = undefined;
    await chmod(executablePath, 0o500);
    const snapshotMetadata = await stat(executablePath);
    if (!snapshotMetadata.isFile() || snapshotMetadata.size !== copied) {
      throw new RuntimeSnapshotError();
    }
    await chmod(snapshotDirectory, 0o500);
    const snapshot = Object.freeze({
      snapshotDirectory,
      executablePath,
      binaryContentSha256: hash.digest("hex"),
      byteLength: copied,
    }) as ExecutableSnapshot;
    ownedExecutableSnapshotFacts.set(snapshot, Object.freeze({
      executablePath: snapshot.executablePath,
      binaryContentSha256: snapshot.binaryContentSha256,
      byteLength: snapshot.byteLength,
    }));
    return snapshot;
  } catch (error: unknown) {
    await destination?.close().catch(() => {});
    await source?.close().catch(() => {});
    if (created) await rm(snapshotDirectory, { recursive: true, force: true }).catch(() => {});
    if (error instanceof RuntimeSnapshotError) throw error;
    throw new RuntimeSnapshotError();
  }
}

export function requireOwnedExecutableSnapshot(
  snapshot: unknown,
): OwnedExecutableSnapshotFacts {
  if (typeof snapshot !== "object" || snapshot === null) throw new RuntimeSnapshotError();
  const facts = ownedExecutableSnapshotFacts.get(snapshot);
  if (!facts) throw new RuntimeSnapshotError();
  return facts;
}

function sameOpenFile(
  before: Awaited<ReturnType<Awaited<ReturnType<typeof open>>["stat"]>>,
  after: Awaited<ReturnType<Awaited<ReturnType<typeof open>>["stat"]>>,
): boolean {
  return (
    before.dev === after.dev &&
    before.ino === after.ino &&
    before.size === after.size &&
    before.mtimeMs === after.mtimeMs
  );
}
