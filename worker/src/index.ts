import {
  ALLOWED_ORIGIN,
  GEMINI_MODEL,
  HEALTH_PATH,
  RANK_PATH,
} from "./constants";
import {
  parseRankRequest,
  type RankResponse,
  type UsageSummary,
} from "./contracts";
import { HttpError } from "./errors";
import { rankWithGemini } from "./gemini";
import {
  hasAllowedOrigin,
  jsonResponse,
  preflightResponse,
  readRequestJson,
  rejectOversizedContentLength,
} from "./http";

type RuntimeEnv = Cloudflare.DevelopmentEnv | Cloudflare.ProductionEnv;

interface RequestMetrics {
  candidateCount: number;
  usage: UsageSummary | null;
}

function isJsonContentType(request: Request): boolean {
  const contentType = request.headers.get("Content-Type");
  return (
    contentType !== null &&
    contentType.split(";", 1)[0]?.trim().toLowerCase() === "application/json"
  );
}

async function hashedClientIp(request: Request): Promise<string> {
  const connectingIp = request.headers.get("CF-Connecting-IP") ?? "unavailable";
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`mro-gemini-proxy:${connectingIp}`),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function enforceRateLimit(
  request: Request,
  env: RuntimeEnv,
): Promise<void> {
  const result = await env.RATE_LIMITER.limit({
    key: await hashedClientIp(request),
  });
  if (!result.success) {
    throw new HttpError(
      429,
      "RATE_LIMITED",
      "Too many AI ranking requests. Please try again shortly.",
      { "Retry-After": "60" },
    );
  }
}

async function handleRank(
  request: Request,
  env: RuntimeEnv,
  metrics: RequestMetrics,
  requestId: string,
): Promise<Response> {
  if (!hasAllowedOrigin(request, ALLOWED_ORIGIN)) {
    throw new HttpError(
      403,
      "ORIGIN_NOT_ALLOWED",
      "This origin is not allowed to use the AI ranking endpoint.",
    );
  }

  if (request.method === "OPTIONS") {
    return preflightResponse(request, ALLOWED_ORIGIN);
  }
  if (request.method !== "POST") {
    throw new HttpError(
      405,
      "METHOD_NOT_ALLOWED",
      "Only POST is allowed for this endpoint.",
      { Allow: "POST, OPTIONS" },
    );
  }
  if (!isJsonContentType(request)) {
    throw new HttpError(
      415,
      "UNSUPPORTED_MEDIA_TYPE",
      "Content-Type must be application/json.",
    );
  }

  rejectOversizedContentLength(request);
  await enforceRateLimit(request, env);
  const rankRequest = parseRankRequest(await readRequestJson(request));
  metrics.candidateCount = rankRequest.candidates.length;

  const result = await rankWithGemini(rankRequest, env.GEMINI_API_KEY);
  metrics.usage = result.usage;
  const response: RankResponse = {
    requestId,
    model: GEMINI_MODEL,
    interpretation: result.interpretation,
    ranked: result.ranked,
    usage: result.usage,
  };
  return jsonResponse(response, 200, request, ALLOWED_ORIGIN, {
    "X-Request-Id": requestId,
  });
}

async function routeRequest(
  request: Request,
  env: RuntimeEnv,
  metrics: RequestMetrics,
  requestId: string,
): Promise<Response> {
  const url = new URL(request.url);
  if (url.search.length > 0) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Query parameters are not supported.",
    );
  }
  if (url.pathname === HEALTH_PATH) {
    if (request.method !== "GET") {
      throw new HttpError(
        405,
        "METHOD_NOT_ALLOWED",
        "Only GET is allowed for this endpoint.",
        { Allow: "GET" },
      );
    }
    return jsonResponse(
      { status: "ok", service: "mro-gemini-proxy", model: GEMINI_MODEL },
      200,
      request,
      null,
      { "X-Request-Id": requestId },
    );
  }
  if (url.pathname === RANK_PATH) {
    return handleRank(request, env, metrics, requestId);
  }
  throw new HttpError(404, "NOT_FOUND", "Route not found.");
}

function errorResponse(
  error: unknown,
  request: Request,
  requestId: string,
): Response {
  const knownError =
    error instanceof HttpError
      ? error
      : new HttpError(500, "INTERNAL_ERROR", "An unexpected error occurred.");
  const isRankRoute = new URL(request.url).pathname === RANK_PATH;
  return jsonResponse(
    {
      requestId,
      error: {
        code: knownError.code,
        message: knownError.message,
      },
    },
    knownError.status,
    request,
    isRankRoute ? ALLOWED_ORIGIN : null,
    {
      ...knownError.responseHeaders,
      "X-Request-Id": requestId,
    },
  );
}

function writeRequestLog(
  requestId: string,
  startedAt: number,
  response: Response,
  metrics: RequestMetrics,
): void {
  const record = JSON.stringify({
    requestId,
    durationMs: Date.now() - startedAt,
    candidateCount: metrics.candidateCount,
    status: response.status,
    inputTokens: metrics.usage?.inputTokens ?? 0,
    outputTokens: metrics.usage?.outputTokens ?? 0,
    thoughtTokens: metrics.usage?.thoughtTokens ?? 0,
    totalTokens: metrics.usage?.totalTokens ?? 0,
  });
  if (response.status >= 500) {
    console.error(record);
  } else {
    console.log(record);
  }
}

async function handleRequest(
  request: Request,
  env: RuntimeEnv,
): Promise<Response> {
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();
  const metrics: RequestMetrics = { candidateCount: 0, usage: null };
  let response: Response;
  try {
    response = await routeRequest(request, env, metrics, requestId);
  } catch (error) {
    response = errorResponse(error, request, requestId);
  }
  writeRequestLog(requestId, startedAt, response, metrics);
  return response;
}

export default {
  async fetch(request: Request, env: RuntimeEnv): Promise<Response> {
    return handleRequest(request, env);
  },
} satisfies ExportedHandler<RuntimeEnv>;
