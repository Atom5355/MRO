import { MAX_REQUEST_BYTES } from "./constants";
import { HttpError } from "./errors";

const JSON_HEADERS: Readonly<Record<string, string>> = {
  "Cache-Control": "no-store",
  "Content-Type": "application/json; charset=utf-8",
  "X-Content-Type-Options": "nosniff",
};

export function hasAllowedOrigin(request: Request, allowedOrigin: string): boolean {
  return request.headers.get("Origin") === allowedOrigin;
}

function applyCors(headers: Headers, request: Request, allowedOrigin: string): void {
  headers.set("Vary", "Origin");
  if (hasAllowedOrigin(request, allowedOrigin)) {
    headers.set("Access-Control-Allow-Origin", allowedOrigin);
  }
}

export function jsonResponse(
  body: unknown,
  status: number,
  request: Request,
  corsOrigin: string | null,
  extraHeaders: Readonly<Record<string, string>> = {},
): Response {
  const headers = new Headers(JSON_HEADERS);
  for (const [name, value] of Object.entries(extraHeaders)) {
    headers.set(name, value);
  }
  if (corsOrigin !== null) {
    applyCors(headers, request, corsOrigin);
  }
  return Response.json(body, { status, headers });
}

export function preflightResponse(
  request: Request,
  allowedOrigin: string,
): Response {
  const requestedMethod = request.headers.get(
    "Access-Control-Request-Method",
  );
  if (requestedMethod !== null && requestedMethod.toUpperCase() !== "POST") {
    throw new HttpError(
      405,
      "METHOD_NOT_ALLOWED",
      "Only POST is allowed for this endpoint.",
      { Allow: "POST, OPTIONS" },
    );
  }

  const requestedHeaders = request.headers.get(
    "Access-Control-Request-Headers",
  );
  if (requestedHeaders !== null) {
    const names = requestedHeaders
      .split(",")
      .map((name) => name.trim().toLowerCase())
      .filter((name) => name.length > 0);
    if (names.some((name) => name !== "content-type")) {
      throw new HttpError(
        400,
        "INVALID_PREFLIGHT",
        "The preflight requested unsupported headers.",
      );
    }
  }

  const headers = new Headers({
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Max-Age": "86400",
    "Cache-Control": "no-store",
    Vary: "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  });
  return new Response(null, { status: 204, headers });
}

export function rejectOversizedContentLength(request: Request): void {
  const contentLength = request.headers.get("Content-Length");
  if (contentLength === null) {
    return;
  }
  if (!/^\d+$/.test(contentLength)) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Content-Length must be a non-negative integer.",
    );
  }
  if (Number(contentLength) > MAX_REQUEST_BYTES) {
    throw new HttpError(
      413,
      "PAYLOAD_TOO_LARGE",
      "Request body exceeds the 256 KiB limit.",
    );
  }
}

async function readStreamWithLimit(
  stream: ReadableStream<Uint8Array> | null,
  maximumBytes: number,
  tooLargeError: HttpError,
): Promise<Uint8Array> {
  if (stream === null) {
    return new Uint8Array();
  }

  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let byteLength = 0;
  try {
    while (true) {
      const result = await reader.read();
      if (result.done) {
        break;
      }
      byteLength += result.value.byteLength;
      if (byteLength > maximumBytes) {
        await reader.cancel();
        throw tooLargeError;
      }
      chunks.push(result.value);
    }
  } finally {
    reader.releaseLock();
  }

  const combined = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return combined;
}

function decodeUtf8(bytes: Uint8Array, invalidMessage: string): string {
  try {
    return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(
      bytes,
    );
  } catch {
    throw new HttpError(400, "INVALID_REQUEST", invalidMessage);
  }
}

export async function readRequestJson(request: Request): Promise<unknown> {
  const bytes = await readStreamWithLimit(
    request.body,
    MAX_REQUEST_BYTES,
    new HttpError(
      413,
      "PAYLOAD_TOO_LARGE",
      "Request body exceeds the 256 KiB limit.",
    ),
  );
  if (bytes.byteLength === 0) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Request body must not be empty.",
    );
  }

  const text = decodeUtf8(bytes, "Request body must be valid UTF-8 JSON.");
  try {
    const value: unknown = JSON.parse(text);
    return value;
  } catch {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Request body must be valid JSON.",
    );
  }
}

export async function readResponseText(
  response: Response,
  maximumBytes: number,
): Promise<string> {
  const contentLength = response.headers.get("Content-Length");
  if (
    contentLength !== null &&
    /^\d+$/.test(contentLength) &&
    Number(contentLength) > maximumBytes
  ) {
    await response.body?.cancel();
    throw new HttpError(
      502,
      "AI_INVALID_RESPONSE",
      "The AI service returned an unusable response.",
    );
  }

  const bytes = await readStreamWithLimit(
    response.body,
    maximumBytes,
    new HttpError(
      502,
      "AI_INVALID_RESPONSE",
      "The AI service returned an unusable response.",
    ),
  );
  try {
    return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(
      bytes,
    );
  } catch {
    throw new HttpError(
      502,
      "AI_INVALID_RESPONSE",
      "The AI service returned an unusable response.",
    );
  }
}
