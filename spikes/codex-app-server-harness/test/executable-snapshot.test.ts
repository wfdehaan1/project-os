import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { chmod, mkdir, mkdtemp, readFile, rename, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  createExecutableSnapshot,
  RuntimeSnapshotError,
} from "../src/adapters/codex/executable-snapshot.ts";

test("snapshot copies open-file bytes once into an immutable private executable", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-snapshot-"));
  const source = join(root, "source-codex");
  await writeFile(source, "owned-runtime-v1", { mode: 0o500 });
  const instance = join(root, "instance");
  await writeFile(join(root, "placeholder"), "unused");
  await mkdir(instance, { mode: 0o700 });

  const snapshot = await createExecutableSnapshot({ sourcePath: source, instanceDirectory: instance });
  assert.equal(await readFile(snapshot.executablePath, "utf8"), "owned-runtime-v1");
  assert.equal((await stat(snapshot.executablePath)).mode & 0o777, 0o500);
  assert.equal((await stat(snapshot.snapshotDirectory)).mode & 0o777, 0o500);
  assert.equal(
    snapshot.binaryContentSha256,
    createHash("sha256").update("owned-runtime-v1").digest("hex"),
  );
  assert.equal(snapshot.byteLength, Buffer.byteLength("owned-runtime-v1"));
});

test("atomic source replacement after open cannot mix later runtime bytes", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-snapshot-replace-"));
  const source = join(root, "codex");
  const replacement = join(root, "replacement");
  const instance = join(root, "instance");
  await writeFile(source, "runtime-old", { mode: 0o500 });
  await writeFile(replacement, "runtime-new-and-different", { mode: 0o500 });
  await mkdir(instance, { mode: 0o700 });

  const snapshot = await createExecutableSnapshot({
    sourcePath: source,
    instanceDirectory: instance,
    afterSourceOpened: async () => {
      await rename(replacement, source);
    },
  });
  assert.equal(await readFile(snapshot.executablePath, "utf8"), "runtime-old");
  assert.equal(await readFile(source, "utf8"), "runtime-new-and-different");
});

test("same-inode mutation after open is rejected instead of snapshotting mixed bytes", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-snapshot-same-inode-"));
  const source = join(root, "codex");
  const instance = join(root, "instance");
  await writeFile(source, "runtime-before-open", { mode: 0o500 });
  await mkdir(instance, { mode: 0o700 });

  await assert.rejects(
    createExecutableSnapshot({
      sourcePath: source,
      instanceDirectory: instance,
      afterSourceOpened: async () => {
        await writeFile(source, "mutated-same-inode-and-size-changed", { mode: 0o500 });
      },
    }),
    (error: unknown) => error instanceof RuntimeSnapshotError,
  );
});

test("snapshot accepts the exact byte limit and rejects one byte over it", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-snapshot-limit-"));
  const exact = join(root, "exact-codex");
  const over = join(root, "over-codex");
  await writeFile(exact, "12345678", { mode: 0o500 });
  await writeFile(over, "123456789", { mode: 0o500 });
  await mkdir(join(root, "instance-exact"), { mode: 0o700 });
  await mkdir(join(root, "instance-over"), { mode: 0o700 });

  const snapshot = await createExecutableSnapshot({
    sourcePath: exact,
    instanceDirectory: join(root, "instance-exact"),
    maximumBytes: 8,
  });
  assert.equal(snapshot.byteLength, 8);
  await assert.rejects(
    createExecutableSnapshot({
      sourcePath: over,
      instanceDirectory: join(root, "instance-over"),
      maximumBytes: 8,
    }),
    (error: unknown) => error instanceof RuntimeSnapshotError,
  );
});

test("snapshot rejects symlinks, empty files, and configured oversize", async () => {
  const root = await mkdtemp(join(tmpdir(), "projectos-snapshot-reject-"));
  const source = join(root, "codex");
  const linked = join(root, "linked-codex");
  await writeFile(source, "too-large", { mode: 0o500 });
  await import("node:fs/promises").then(({ symlink }) =>
    Promise.all([
      mkdir(join(root, "instance-a"), { mode: 0o700 }),
      mkdir(join(root, "instance-b"), { mode: 0o700 }),
      symlink(source, linked),
    ]),
  );

  await assert.rejects(
    createExecutableSnapshot({ sourcePath: linked, instanceDirectory: join(root, "instance-a") }),
    (error: unknown) => error instanceof RuntimeSnapshotError,
  );
  await assert.rejects(
    createExecutableSnapshot({
      sourcePath: source,
      instanceDirectory: join(root, "instance-b"),
      maximumBytes: 2,
    }),
    (error: unknown) => error instanceof RuntimeSnapshotError,
  );

  const empty = join(root, "empty");
  const emptyInstance = join(root, "instance-empty");
  await writeFile(empty, "", { mode: 0o500 });
  await mkdir(emptyInstance, { mode: 0o700 });
  await chmod(empty, 0o500);
  await assert.rejects(
    createExecutableSnapshot({ sourcePath: empty, instanceDirectory: emptyInstance }),
    (error: unknown) => error instanceof RuntimeSnapshotError,
  );
});
