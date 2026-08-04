import type { ChildProcessWithoutNullStreams } from "node:child_process";
import { StringDecoder } from "node:string_decoder";

import {
  HandshakeProtocolError,
  initializeRequest,
  initializedNotification,
  validateInitializeResponse,
  type CodexInitializeRequest,
  type CodexInitializedNotification,
} from "./protocol.ts";
import type { ProtocolBoundary } from "./protocol-contract.ts";

const MAX_PROTOCOL_LINE_BYTES = 1024 * 1024;

export interface StructuralProtocolTranscriptEntry {
  readonly attemptId: string;
  readonly sequence: number;
  readonly direction:
    | "outbound_request"
    | "outbound_notification"
    | "inbound_response"
    | "inbound_notification"
    | "inbound_request_or_event";
  readonly method: string;
  readonly requestIdClass: "initialize" | "unrelated" | "server" | "none";
  readonly classification:
    | "sent_experimental_api_disabled"
    | "sent"
    | "matched"
    | "unrelated"
    | "semantic"
    | "forbidden_side_effect"
    | "unknown";
}

export interface JsonlRpcConnectionOptions {
  readonly attemptId: string;
  readonly protocolBoundary: ProtocolBoundary;
  readonly transcriptSink?: (entry: StructuralProtocolTranscriptEntry) => void;
}

export class JsonlRpcConnection {
  readonly #child: ChildProcessWithoutNullStreams;
  readonly #attemptId: string;
  readonly #protocolBoundary: ProtocolBoundary;
  readonly #transcriptSink: ((entry: StructuralProtocolTranscriptEntry) => void) | undefined;
  #sequence = 0;

  constructor(child: ChildProcessWithoutNullStreams, options: JsonlRpcConnectionOptions) {
    this.#child = child;
    this.#attemptId = options.attemptId;
    this.#protocolBoundary = options.protocolBoundary;
    this.#transcriptSink = options.transcriptSink;
  }

  async initialize(timeoutMs: number): Promise<void> {
    return new Promise((resolveHandshake, rejectHandshake) => {
      let buffer = "";
      let settled = false;
      let initializeResponseAccepted = false;
      const decoder = new StringDecoder("utf8");

      const finish = (error?: Error): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        this.#child.stdout.off("data", onData);
        this.#child.stdout.off("end", onEnd);
        this.#child.stdout.off("error", onStreamError);
        this.#child.off("exit", onExit);
        if (error) rejectHandshake(error);
        else resolveHandshake();
      };
      const onEnd = (): void => finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      const onExit = (): void => finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      const onStreamError = (): void =>
        finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      const onData = (chunk: Buffer): void => {
        buffer += decoder.write(chunk);
        if (Buffer.byteLength(buffer) > MAX_PROTOCOL_LINE_BYTES) {
          finish(new HandshakeProtocolError("malformed_handshake_response"));
          return;
        }
        while (buffer.includes("\n") && !settled) {
          const lineEnd = buffer.indexOf("\n");
          const line = buffer.slice(0, lineEnd).trimEnd();
          buffer = buffer.slice(lineEnd + 1);
          if (!line) continue;
          let parsed: unknown;
          try {
            parsed = JSON.parse(line);
          } catch {
            finish(new HandshakeProtocolError("malformed_handshake_response"));
            return;
          }
          try {
            if (isObject(parsed) && typeof parsed.method === "string") {
              const inboundRequest = "id" in parsed;
              const classification = this.#protocolBoundary.classifyInbound(
                parsed.method,
                inboundRequest ? "server_request" : "server_notification",
              );
              this.#record({
                direction: inboundRequest ? "inbound_request_or_event" : "inbound_notification",
                method: parsed.method,
                requestIdClass: inboundRequest ? "server" : "none",
                classification:
                  classification === "semantic_notification"
                    ? "semantic"
                    : classification === "forbidden"
                      ? "forbidden_side_effect"
                      : "unknown",
              });
              if (classification !== "semantic_notification") {
                finish(new HandshakeProtocolError("unsupported_dispatch"));
                return;
              }
              continue;
            }
            const response = validateInitializeResponse(parsed);
            this.#record({
              direction: "inbound_response",
              method: "initialize",
              requestIdClass: response === "match" ? "initialize" : "unrelated",
              classification: response === "match" ? "matched" : "unrelated",
            });
            if (response === "unrelated") continue;
            if (initializeResponseAccepted) {
              finish(new HandshakeProtocolError("malformed_handshake_response"));
              return;
            }
            initializeResponseAccepted = true;
            this.#writeInitialized((error) => finish(error));
          } catch (error: unknown) {
            finish(
              error instanceof Error
                ? error
                : new HandshakeProtocolError("malformed_handshake_response"),
            );
          }
        }
      };

      this.#child.stdout.on("data", onData);
      this.#child.stdout.once("end", onEnd);
      this.#child.stdout.once("error", onStreamError);
      this.#child.once("exit", onExit);
      const timer = setTimeout(
        () => finish(new HandshakeProtocolError("initialization_timeout")),
        timeoutMs,
      );
      timer.unref();
      this.#writeInitialize((error) => {
        if (error) finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      });
      if (this.#child.stdout.readableEnded || this.#child.exitCode !== null) onExit();
    });
  }

  closeInput(): void {
    if (!this.#child.stdin.destroyed) this.#child.stdin.end();
  }

  #writeInitialize(callback: (error?: Error) => void): void {
    const request = initializeRequest();
    this.#protocolBoundary.assertClientRequest(request.method);
    this.#writeJsonl(request, (error) => {
      if (!error) {
        this.#record({
          direction: "outbound_request",
          method: request.method,
          requestIdClass: "initialize",
          classification: "sent_experimental_api_disabled",
        });
      }
      callback(error);
    });
  }

  #writeInitialized(callback: (error?: Error) => void): void {
    const notification = initializedNotification();
    this.#protocolBoundary.assertClientNotification(notification.method);
    this.#writeJsonl(notification, (error) => {
      if (!error) {
        this.#record({
          direction: "outbound_notification",
          method: notification.method,
          requestIdClass: "none",
          classification: "sent",
        });
      }
      callback(error);
    });
  }

  #writeJsonl(
    value: CodexInitializeRequest | CodexInitializedNotification,
    callback: (error?: Error) => void,
  ): void {
    this.#child.stdin.write(`${JSON.stringify(value)}\n`, "utf8", (error) =>
      callback(error ?? undefined),
    );
  }

  #record(
    entry: Omit<StructuralProtocolTranscriptEntry, "attemptId" | "sequence">,
  ): void {
    this.#transcriptSink?.(
      Object.freeze({
        attemptId: this.#attemptId,
        sequence: ++this.#sequence,
        ...entry,
      }),
    );
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
