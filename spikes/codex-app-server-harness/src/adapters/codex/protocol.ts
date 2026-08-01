import type { ProviderFailureCode } from "../../core/failures.ts";

export const INITIALIZE_REQUEST_ID = 1;

export interface CodexInitializeRequest {
  readonly id: number;
  readonly method: "initialize";
  readonly params: {
    readonly clientInfo: {
      readonly name: "ProjectOS";
      readonly title: "ProjectOS validation harness";
      readonly version: "0.1.0";
    };
    readonly capabilities: { readonly experimentalApi: false };
  };
}

export interface CodexInitializedNotification {
  readonly method: "initialized";
}

export function initializeRequest(): CodexInitializeRequest {
  return {
    id: INITIALIZE_REQUEST_ID,
    method: "initialize",
    params: {
      clientInfo: {
        name: "ProjectOS",
        title: "ProjectOS validation harness",
        version: "0.1.0",
      },
      capabilities: { experimentalApi: false },
    },
  };
}

export function initializedNotification(): CodexInitializedNotification {
  return { method: "initialized" };
}

export class HandshakeProtocolError extends Error {
  readonly code: ProviderFailureCode;

  constructor(code: ProviderFailureCode) {
    super(code);
    this.name = "HandshakeProtocolError";
    this.code = code;
  }
}

export function validateInitializeResponse(value: unknown): "match" | "unrelated" {
  if (!isObject(value)) throw new HandshakeProtocolError("malformed_handshake_response");
  if (!("id" in value)) return "unrelated";
  if (value.id !== INITIALIZE_REQUEST_ID) return "unrelated";
  if ("error" in value) throw new HandshakeProtocolError("initialization_rejected");
  if (!("result" in value) || !isObject(value.result)) {
    throw new HandshakeProtocolError("malformed_handshake_response");
  }
  return "match";
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
