export const ALLOWED_ORIGIN = "https://atom5355.github.io";
export const RANK_PATH = "/v1/rank";
export const HEALTH_PATH = "/healthz";

export const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1/interactions";
export const GEMINI_MODEL = "gemini-3.6-flash";

export const MAX_REQUEST_BYTES = 256 * 1024;
export const MAX_UPSTREAM_RESPONSE_BYTES = 1024 * 1024;
export const UPSTREAM_TIMEOUT_MS = 30_000;
export const RETRY_DELAY_MS = 200;

export const MAX_CANDIDATES = 250;
export const MAX_RANKED_RESULTS = 50;
export const MAX_QUERY_LENGTH = 500;
export const MAX_IDENTIFIER_LENGTH = 160;
export const MAX_DESCRIPTION_LENGTH = 1000;
export const MAX_INTERPRETATION_LENGTH = 500;
export const MAX_REASON_LENGTH = 300;

export const INPUT_PRICE_PER_MILLION = 1.5;
export const OUTPUT_PRICE_PER_MILLION = 7.5;
