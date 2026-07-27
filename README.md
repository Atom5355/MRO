# MRO Engine

MRO Engine is a Flutter web inventory search application backed by a local,
deterministic search index. Natural-language result ranking is optional and is
performed through the `mro-gemini-proxy` Cloudflare Worker; the browser never
receives or sends a Gemini API key.

## Architecture

- The workbook is loaded in Flutter and indexed locally. Exact W/item, legacy,
  manufacturer-part, and supplier-part identifiers are resolved locally.
- Filters run locally and can be changed without another AI request.
- For a natural-language query, at most 250 locally selected candidates are
  sent to the Worker. AI-ranked rows are placed first and the remaining local
  matches are retained.
- The Worker fixes the Gemini endpoint, model, prompt, structured-output schema,
  thinking level, output limit, CORS origin, and rate limit. Client requests can
  supply only a query and bounded candidate records.

## Verification

```powershell
Set-Location D:\Projects\MROEngine\mro_engine\worker
npm ci
npm run check
npm run deploy:dry-run

Set-Location D:\Projects\MROEngine\mro_engine
flutter pub get
flutter analyze
flutter test
```

The GitHub Pages workflow performs the Worker checks, Flutter analysis and
tests, and a production web build before publishing.

## Worker deployment

Wrangler 4.x and Node.js 22 or newer are required. Keep local credentials in
`worker/.dev.vars`, which is ignored by Git. Never commit a Gemini key.

1. Keep any previously exposed Gemini key revoked.
2. Put the rerolled production key into the interactive Wrangler secret prompt:

   ```powershell
   Set-Location D:\Projects\MROEngine\mro_engine\worker
   npx wrangler secret put GEMINI_API_KEY --env production
   ```

3. Deploy manually:

   ```powershell
   npm run deploy:production
   ```

4. Copy the deployed Worker's full `https://...workers.dev/v1/rank` URL into
   the GitHub repository variable `AI_SEARCH_ENDPOINT`. For example, with the
   GitHub CLI authenticated for this repository:

   ```powershell
   gh variable set AI_SEARCH_ENDPOINT --body "https://<workers-dev-host>/v1/rank"
   ```

5. Re-run the GitHub Pages workflow and smoke-test a duplicate legacy number,
   an exact W/MPN/supplier identifier, a natural-language query, Worker failure
   fallback, and filter changes after an AI-ranked search.

The Worker permits anonymous requests only from
`https://atom5355.github.io` and rate-limits each hashed connecting IP to 20
requests per minute. CORS is not authentication: configure Google project
quotas and billing alerts, and monitor Worker latency, 429/5xx rates, and token
spend after rollout.

Production Flutter builds require the public endpoint:

```powershell
flutter build web --release --dart-define=AI_SEARCH_ENDPOINT="https://<workers-dev-host>/v1/rank"
```
