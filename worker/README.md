# MRO Gemini ranking Worker

This Worker is the only component allowed to hold the Gemini API key. It accepts a bounded list of MRO search candidates from the Flutter client, asks the fixed `gemini-3.6-flash` model to rank them through Google's stable `v1` Interactions endpoint, validates the response, and returns sanitized ranking metadata.

## Public routes

- `POST /v1/rank`
- `OPTIONS /v1/rank`
- `GET /healthz`

Browser ranking requests must use the exact origin `https://atom5355.github.io`. CORS is not authentication; the Worker also applies the configured 20 requests/minute Rate Limiting binding per hashed connecting IP. Keep Google project quotas and billing alerts configured as a second cost control.

### Rank request

```json
{
  "query": "replacement conveyor bearing",
  "candidates": [
    {
      "id": 0,
      "itemNumber": "W-100",
      "legacyNumber": "A49",
      "description": "Stainless steel replacement bearing",
      "manufacturer": "SICK",
      "manufacturerPartNumber": "MFR-100",
      "supplierPartNumber": "SUP-100",
      "location": "A-01"
    }
  ]
}
```

Requests are limited to 256 KiB, a 500-character query, and 1–250 candidates. Identifier, manufacturer, and location fields are limited to 160 characters; descriptions are limited to 1,000. Candidate IDs must be unique non-negative integers. Unknown fields are rejected so callers cannot select another model, prompt, endpoint, tool, or generation configuration.

### Rank response

```json
{
  "requestId": "00000000-0000-4000-8000-000000000000",
  "model": "gemini-3.6-flash",
  "interpretation": "A replacement bearing for conveyor service",
  "ranked": [
    {
      "id": 0,
      "relevance": 94,
      "reason": "The description and application match."
    }
  ],
  "usage": {
    "inputTokens": 100,
    "outputTokens": 50,
    "thoughtTokens": 25,
    "totalTokens": 175,
    "estimatedCostUsd": 0.0007125
  }
}
```

The Worker returns no more than 50 unique supplied IDs, sorted by validated relevance from 0–100. Interpretation is capped at 500 characters and reasons at 300.

## Local development

Requirements: Node.js 22 or later and npm.

```powershell
Set-Location D:\Projects\MROEngine\mro_engine\worker
npm install
Copy-Item .dev.vars.example .dev.vars
```

Replace the placeholder in `.dev.vars` locally, then run:

```powershell
npm run types
npm run check
npm run dev
```

`.dev.vars`, `.env`, Wrangler state, build output, and dependencies are ignored. Never commit or paste a real API key into source, config, test fixtures, command arguments, or logs.

## Validation and deployment

```powershell
npm run types:check
npm run typecheck
npm test
npm run deploy:dry-run
```

Development and production are separate named Workers and use separate Rate Limiting namespaces. Secrets are also environment-specific and are not inherited.

Set each secret through Wrangler's interactive prompt and deploy explicitly:

```powershell
npx wrangler secret put GEMINI_API_KEY --env development
npm run deploy:development

npx wrangler secret put GEMINI_API_KEY --env production
npm run deploy:production
```

After production deployment, set the GitHub repository variable `AI_SEARCH_ENDPOINT` to the full production workers.dev URL ending in `/v1/rank`, then redeploy the Flutter web app. Do not deploy the unnamed root Worker.

Structured logs contain only request ID, duration, candidate count, HTTP status, and token counts. They intentionally exclude API keys, IP addresses, search queries, candidate content, provider bodies, and model output.
Cloudflare invocation logs are disabled so the platform does not separately
persist enriched request headers or client network metadata; sanitized custom
logs and traces remain enabled.
