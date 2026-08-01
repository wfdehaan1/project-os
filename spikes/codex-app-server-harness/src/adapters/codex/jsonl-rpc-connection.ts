import type { ChildProcessWithoutNullStreams } from "node:child_process";
import { StringDecoder } from "node:string_decoder";

import {
  HandshakeProtocolError,
  initializeRequest,
  initializedNotification,
  validateInitializeResponse,
} from "./protocol.ts";

const MAX_PROTOCOL_LINE_BYTES = 1024 * 1024;

export class JsonlRpcConnection {
  readonly #child: ChildProcessWithoutNullStreams;

  constructor(child: ChildProcessWithoutNullStreams) {
    this.#child = child;
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
            if (validateInitializeResponse(parsed) === "unrelated") continue;
            if (initializeResponseAccepted) {
              finish(new HandshakeProtocolError("malformed_handshake_response"));
              return;
            }
            initializeResponseAccepted = true;
            this.#write(initializedNotification(), (error) => finish(error));
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
      this.#write(initializeRequest(), (error) => {
        if (error) finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      });
      if (this.#child.stdout.readableEnded || this.#child.exitCode !== null) onExit();
    });
  }

  closeInput(): void {
    if (!this.#child.stdin.destroyed) this.#child.stdin.end();
  }

  #write(value: unknown, callback: (error?: Error) => void): void {
    this.#child.stdin.write(`${JSON.stringify(value)}\n`, "utf8", (error) => callback(error ?? undefined));
  }
}
