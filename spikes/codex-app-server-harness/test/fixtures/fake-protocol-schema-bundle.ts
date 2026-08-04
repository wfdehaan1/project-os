import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

export const FAKE_CLIENT_REQUESTS = ["account/read", "initialize", "thread/start"] as const;
export const FAKE_CLIENT_NOTIFICATIONS = ["initialized"] as const;
export const FAKE_SERVER_NOTIFICATIONS = ["error", "thread/started"] as const;
export const FAKE_SERVER_REQUESTS = ["item/tool/call"] as const;

export async function writeFakeProtocolSchemaBundle(
  root: string,
  options: { readonly drift?: boolean; readonly reverseCreationOrder?: boolean } = {},
): Promise<{ readonly jsonDirectory: string; readonly typescriptDirectory: string }> {
  const jsonDirectory = join(root, "json");
  const typescriptDirectory = join(root, "typescript");
  await mkdir(join(jsonDirectory, "nested"), { recursive: true });
  await mkdir(typescriptDirectory, { recursive: true });

  const files = [
    {
      path: join(jsonDirectory, "ClientRequest.json"),
      value: methodSchema("ClientRequest", FAKE_CLIENT_REQUESTS),
    },
    {
      path: join(jsonDirectory, "ClientNotification.json"),
      value: methodSchema("ClientNotification", FAKE_CLIENT_NOTIFICATIONS),
    },
    {
      path: join(jsonDirectory, "ServerNotification.json"),
      value: methodSchema("ServerNotification", FAKE_SERVER_NOTIFICATIONS),
    },
    {
      path: join(jsonDirectory, "ServerRequest.json"),
      value: methodSchema("ServerRequest", FAKE_SERVER_REQUESTS),
    },
    {
      path: join(jsonDirectory, "nested", "Other.json"),
      value: "{}\n",
    },
    {
      path: join(typescriptDirectory, "ClientRequest.ts"),
      value: `export type ClientRequest = ${FAKE_CLIENT_REQUESTS.map((value) => JSON.stringify(value)).join(" | ")};\n`,
    },
    {
      path: join(typescriptDirectory, "ServerRequest.ts"),
      value: `export type ServerRequest = ${FAKE_SERVER_REQUESTS.map((value) => JSON.stringify(value)).join(" | ")};${options.drift ? " // drift" : ""}\n`,
    },
  ];
  if (options.reverseCreationOrder) files.reverse();
  for (const file of files) await writeFile(file.path, file.value, { mode: 0o600 });
  return { jsonDirectory, typescriptDirectory };
}

function methodSchema(title: string, methods: readonly string[]): string {
  return `${JSON.stringify({
    title,
    oneOf: methods.map((method) => ({
      type: "object",
      properties: { method: { type: "string", enum: [method] } },
    })),
  }, null, 2)}\n`;
}
