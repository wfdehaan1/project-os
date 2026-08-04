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

export interface AuthenticationExchangeResult {
  readonly state:
    | "signed_out"
    | "authenticated_chatgpt"
    | "cancelled"
    | "expired"
    | "failed"
    | "secure_storage_unavailable";
  readonly planCategory: "pro" | "other" | "unknown";
  readonly expectedPro: "matched" | "not_matched" | "unknown";
  readonly logoutOutcome: "completed" | "not_needed";
  /** A disposable profile that was already signed in is never mutated or claimed as browser proof. */
  readonly preexistingAuthentication: boolean;
}

export interface AuthenticationExchangeOptions {
  readonly timeoutMs: number;
  readonly interactive: boolean;
  /** The URL is intentionally an ephemeral adapter callback, never evidence. */
  readonly openLoginUrl?: (url: string) => Promise<void> | void;
  readonly deviceCodeRecovery?: boolean;
}

export class JsonlRpcConnection {
  readonly #child: ChildProcessWithoutNullStreams;
  readonly #attemptId: string;
  readonly #protocolBoundary: ProtocolBoundary;
  readonly #transcriptSink: ((entry: StructuralProtocolTranscriptEntry) => void) | undefined;
  #sequence = 0;
  #loginCompletion: AuthenticationExchangeResult["state"] | undefined;

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

  async validateManagedChatgptAuthentication(
    options: AuthenticationExchangeOptions,
  ): Promise<AuthenticationExchangeResult> {
    const initial = await this.#request("account/read", {}, 2, options.timeoutMs);
    const account = accountState(initial);
    if (account.state === "authenticated_chatgpt") {
      return { ...account, logoutOutcome: "not_needed", preexistingAuthentication: true };
    }
    if (account.state !== "signed_out" || !options.interactive) {
      return { ...account, logoutOutcome: "not_needed", preexistingAuthentication: false };
    }

    const started = await this.#request(
      "account/login/start", { type: options.deviceCodeRecovery ? "device_code" : "chatgpt" }, 3, options.timeoutMs,
      (message) => {
        const url = loginUrl(message);
        if (url) return options.openLoginUrl?.(url);
      },
    );
    void started;
    const terminal = await this.#waitForLoginCompletion(options.timeoutMs);
    if (terminal !== "authenticated_chatgpt") {
      // Cancellation is allowed only to dispose the runtime-owned login attempt.
      await this.#request("account/login/cancel", {}, 4, options.timeoutMs).catch(() => {});
      return {
        state: terminal,
        planCategory: "unknown",
        expectedPro: "unknown",
        logoutOutcome: "not_needed",
        preexistingAuthentication: false,
      };
    }
    const refreshed = accountState(await this.#request("account/read", {}, 6, options.timeoutMs));
    if (refreshed.state !== "authenticated_chatgpt") {
      return { ...refreshed, logoutOutcome: "not_needed", preexistingAuthentication: false };
    }
    await this.#request("account/logout", {}, 7, options.timeoutMs);
    return { ...refreshed, logoutOutcome: "completed", preexistingAuthentication: false };
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
    value: CodexInitializeRequest | CodexInitializedNotification | Record<string, unknown>,
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

  #request(
    method: "account/read" | "account/login/start" | "account/login/cancel" | "account/logout",
    params: Record<string, unknown>,
    id: number,
    timeoutMs: number,
    afterResponse?: (response: Record<string, unknown>) => Promise<void> | void,
  ): Promise<Record<string, unknown>> {
    this.#protocolBoundary.assertClientRequest(method);
    return new Promise((resolveRequest, rejectRequest) => {
      let buffer = "";
      let settled = false;
      const decoder = new StringDecoder("utf8");
      const finish = (error?: Error, result?: Record<string, unknown>): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        this.#child.stdout.off("data", onData);
        this.#child.stdout.off("end", onEnd);
        this.#child.stdout.off("error", onEnd);
        this.#child.off("exit", onEnd);
        if (error) rejectRequest(error); else resolveRequest(result ?? {});
      };
      const onEnd = (): void => finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      const onData = (chunk: Buffer): void => {
        buffer += decoder.write(chunk);
        if (Buffer.byteLength(buffer) > MAX_PROTOCOL_LINE_BYTES) return finish(new HandshakeProtocolError("malformed_handshake_response"));
        while (buffer.includes("\n") && !settled) {
          const end = buffer.indexOf("\n"); const line = buffer.slice(0, end).trimEnd(); buffer = buffer.slice(end + 1);
          if (!line) continue;
          let parsed: unknown; try { parsed = JSON.parse(line); } catch { finish(new HandshakeProtocolError("malformed_handshake_response")); return; }
          if (isObject(parsed) && typeof parsed.method === "string") {
            const direction = "id" in parsed ? "server_request" : "server_notification";
            const classification = this.#protocolBoundary.classifyInbound(parsed.method, direction);
            this.#record({ direction: direction === "server_request" ? "inbound_request_or_event" : "inbound_notification", method: parsed.method, requestIdClass: direction === "server_request" ? "server" : "none", classification: classification === "semantic_notification" ? "semantic" : classification === "forbidden" ? "forbidden_side_effect" : "unknown" });
            if (classification !== "semantic_notification") finish(new HandshakeProtocolError("unsupported_dispatch"));
            if (parsed.method === "account/login/completed") this.#loginCompletion = completionState(parsed);
            continue;
          }
          if (!isObject(parsed) || parsed.id !== id) {
            this.#record({ direction: "inbound_response", method, requestIdClass: "unrelated", classification: "unrelated" });
            continue;
          }
          this.#record({ direction: "inbound_response", method, requestIdClass: "initialize", classification: "matched" });
          if ("error" in parsed) { finish(new HandshakeProtocolError("authentication_failed")); return; }
          if (!hasSafeAuthenticationResult(method, parsed.result)) {
            finish(new HandshakeProtocolError("malformed_handshake_response"));
            return;
          }
          Promise.resolve(afterResponse?.(parsed)).then(() => finish(undefined, parsed), () => finish(new HandshakeProtocolError("authentication_failed")));
        }
      };
      const timer = setTimeout(() => finish(new HandshakeProtocolError("authentication_timeout")), timeoutMs); timer.unref();
      this.#child.stdout.on("data", onData); this.#child.stdout.once("end", onEnd); this.#child.stdout.once("error", onEnd); this.#child.once("exit", onEnd);
      this.#writeJsonl({ id, method, params }, (error) => {
        if (error) return finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
        this.#record({ direction: "outbound_request", method, requestIdClass: "initialize", classification: "sent" });
      });
    });
  }

  #waitForLoginCompletion(timeoutMs: number): Promise<AuthenticationExchangeResult["state"]> {
    return new Promise((resolveWait, rejectWait) => {
      if (this.#loginCompletion) { resolveWait(this.#loginCompletion); return; }
      let buffer = ""; let settled = false; const decoder = new StringDecoder("utf8");
      const finish = (error?: Error, state?: AuthenticationExchangeResult["state"]): void => { if (settled) return; settled = true; clearTimeout(timer); this.#child.stdout.off("data", onData); this.#child.stdout.off("end", onEnd); this.#child.stdout.off("error", onEnd); this.#child.off("exit", onEnd); if (error) rejectWait(error); else resolveWait(state ?? "failed"); };
      const onEnd = (): void => finish(new HandshakeProtocolError("unexpected_exit_or_eof"));
      const onData = (chunk: Buffer): void => { buffer += decoder.write(chunk); if (Buffer.byteLength(buffer) > MAX_PROTOCOL_LINE_BYTES) { finish(new HandshakeProtocolError("malformed_handshake_response")); return; } while (buffer.includes("\n") && !settled) { const end = buffer.indexOf("\n"); const line = buffer.slice(0, end).trimEnd(); buffer = buffer.slice(end + 1); if (!line) continue; let parsed: unknown; try { parsed = JSON.parse(line); } catch { finish(new HandshakeProtocolError("malformed_handshake_response")); return; } if (!isObject(parsed) || typeof parsed.method !== "string") continue; const classification = this.#protocolBoundary.classifyInbound(parsed.method, "server_notification"); this.#record({ direction: "inbound_notification", method: parsed.method, requestIdClass: "none", classification: classification === "semantic_notification" ? "semantic" : classification === "forbidden" ? "forbidden_side_effect" : "unknown" }); if (classification !== "semantic_notification") { finish(new HandshakeProtocolError("unsupported_dispatch")); return; } if (parsed.method === "account/login/completed") { this.#loginCompletion = completionState(parsed); finish(undefined, this.#loginCompletion); } } };
      const timer = setTimeout(() => finish(new HandshakeProtocolError("authentication_timeout")), timeoutMs); timer.unref(); this.#child.stdout.on("data", onData); this.#child.stdout.once("end", onEnd); this.#child.stdout.once("error", onEnd); this.#child.once("exit", onEnd);
    });
  }
}

function accountState(message: Record<string, unknown>): Omit<AuthenticationExchangeResult, "logoutOutcome" | "preexistingAuthentication"> {
  const result = message.result as Record<string, unknown>;
  const account = result.account;
  if (account === null) return { state: "signed_out", planCategory: "unknown", expectedPro: "unknown" };
  if (!isObject(account)) return { state: "failed", planCategory: "unknown", expectedPro: "unknown" };
  const method = typeof account.type === "string" ? account.type.toLowerCase() : "";
  if (method !== "chatgpt") return { state: "failed", planCategory: "unknown", expectedPro: "unknown" };
  const plan = typeof account.plan === "string" ? account.plan.toLowerCase() : "";
  const planCategory = plan === "pro" ? "pro" : plan ? "other" : "unknown";
  return { state: "authenticated_chatgpt", planCategory, expectedPro: planCategory === "pro" ? "matched" : planCategory === "other" ? "not_matched" : "unknown" };
}

function completionState(message: Record<string, unknown>): AuthenticationExchangeResult["state"] {
  const params = isObject(message.params) ? message.params : {};
  const status = typeof params.status === "string" ? params.status.toLowerCase() : "failed";
  if (status === "completed" || status === "success") return "authenticated_chatgpt";
  if (status === "cancelled") return "cancelled";
  if (status === "expired") return "expired";
  if (status === "secure_storage_unavailable") return "secure_storage_unavailable";
  return "failed";
}

function loginUrl(message: Record<string, unknown>): string | undefined {
  const result = isObject(message.result) ? message.result : undefined;
  return result && typeof result.url === "string" && /^https:\/\//u.test(result.url) ? result.url : undefined;
}

function hasSafeAuthenticationResult(
  method: "account/read" | "account/login/start" | "account/login/cancel" | "account/logout",
  result: unknown,
): boolean {
  if (!isObject(result)) return false;
  if (method === "account/read") {
    if (!hasExactKeys(result, ["account"])) return false;
    if (result.account === null) return true;
    return isObject(result.account) && hasExactKeys(result.account, ["plan", "type"]) &&
      typeof result.account.type === "string" && typeof result.account.plan === "string";
  }
  if (method === "account/login/start") {
    return hasExactKeys(result, ["url"]) && typeof result.url === "string" && /^https:\/\//u.test(result.url);
  }
  return hasExactKeys(result, []);
}

function hasExactKeys(value: Record<string, unknown>, keys: readonly string[]): boolean {
  const actual = Object.keys(value).sort();
  return actual.length === keys.length && actual.every((key, index) => key === [...keys].sort()[index]);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
