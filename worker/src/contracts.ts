import {
  MAX_CANDIDATES,
  MAX_DESCRIPTION_LENGTH,
  MAX_IDENTIFIER_LENGTH,
  MAX_QUERY_LENGTH,
  MAX_REASON_LENGTH,
} from "./constants";
import { HttpError } from "./errors";

export interface RankCandidate {
  id: number;
  itemNumber: string;
  legacyNumber: string;
  description: string;
  manufacturer: string;
  manufacturerPartNumber: string;
  supplierPartNumber: string;
  location: string;
}

export interface RankRequest {
  query: string;
  candidates: RankCandidate[];
}

export interface RankedRecord {
  id: number;
  relevance: number;
  reason: string;
}

export interface UsageSummary {
  inputTokens: number;
  outputTokens: number;
  thoughtTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
}

export interface RankResponse {
  requestId: string;
  model: string;
  interpretation: string;
  ranked: RankedRecord[];
  usage: UsageSummary;
}

const TOP_LEVEL_KEYS = new Set(["query", "candidates"]);
const CANDIDATE_KEYS = new Set([
  "id",
  "itemNumber",
  "legacyNumber",
  "description",
  "manufacturer",
  "manufacturerPartNumber",
  "supplierPartNumber",
  "location",
]);

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function rejectUnknownKeys(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
  context: string,
): void {
  if (Object.keys(value).some((key) => !allowed.has(key))) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      `${context} contains unsupported fields.`,
    );
  }
}

function boundedString(
  value: Record<string, unknown>,
  field: string,
  maximumLength: number,
): string {
  const raw = value[field];
  if (typeof raw !== "string") {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      `${field} must be a string.`,
    );
  }
  if (raw.length > maximumLength) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      `${field} exceeds its maximum length.`,
    );
  }
  return raw.trim();
}

function parseCandidate(value: unknown, seenIds: Set<number>): RankCandidate {
  if (!isRecord(value)) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Each candidate must be an object.",
    );
  }
  rejectUnknownKeys(value, CANDIDATE_KEYS, "Candidate");

  const id = value.id;
  if (
    typeof id !== "number" ||
    !Number.isSafeInteger(id) ||
    id < 0 ||
    id > 2_147_483_647
  ) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Candidate id must be a non-negative integer.",
    );
  }
  if (seenIds.has(id)) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Candidate ids must be unique.",
    );
  }
  seenIds.add(id);

  return {
    id,
    itemNumber: boundedString(value, "itemNumber", MAX_IDENTIFIER_LENGTH),
    legacyNumber: boundedString(value, "legacyNumber", MAX_IDENTIFIER_LENGTH),
    description: boundedString(value, "description", MAX_DESCRIPTION_LENGTH),
    manufacturer: boundedString(value, "manufacturer", MAX_IDENTIFIER_LENGTH),
    manufacturerPartNumber: boundedString(
      value,
      "manufacturerPartNumber",
      MAX_IDENTIFIER_LENGTH,
    ),
    supplierPartNumber: boundedString(
      value,
      "supplierPartNumber",
      MAX_IDENTIFIER_LENGTH,
    ),
    location: boundedString(value, "location", MAX_IDENTIFIER_LENGTH),
  };
}

export function parseRankRequest(value: unknown): RankRequest {
  if (!isRecord(value)) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "Request body must be a JSON object.",
    );
  }
  rejectUnknownKeys(value, TOP_LEVEL_KEYS, "Request body");

  const query = boundedString(value, "query", MAX_QUERY_LENGTH);
  if (query.length === 0) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      "query must not be empty.",
    );
  }

  const rawCandidates = value.candidates;
  if (
    !Array.isArray(rawCandidates) ||
    rawCandidates.length === 0 ||
    rawCandidates.length > MAX_CANDIDATES
  ) {
    throw new HttpError(
      400,
      "INVALID_REQUEST",
      `candidates must contain between 1 and ${MAX_CANDIDATES} records.`,
    );
  }

  const seenIds = new Set<number>();
  return {
    query,
    candidates: rawCandidates.map((candidate) =>
      parseCandidate(candidate, seenIds),
    ),
  };
}

export function truncateText(value: string, maximumLength: number): string {
  return value.trim().slice(0, maximumLength);
}

export function normalizeReason(value: string): string {
  return truncateText(value, MAX_REASON_LENGTH);
}
