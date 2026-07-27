import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

process.env.GEMINI_API_KEY = "test-only-key";

export default defineConfig({
  plugins: [
    cloudflareTest({
      main: "./src/index.ts",
      miniflare: {
        bindings: {
          GEMINI_API_KEY: "test-only-key",
        },
      },
      wrangler: {
        configPath: "./wrangler.jsonc",
        environment: "development",
      },
    }),
  ],
});
