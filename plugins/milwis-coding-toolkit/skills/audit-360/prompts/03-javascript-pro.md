# Prompt for `javascript-pro` — deep JS/TS audit (skip if none detected)

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: javascript-pro
description: JS/TS audit — XSS, async, npm supply chain, AI anti-patterns
prompt: |
  You are auditing the JavaScript / TypeScript code in the application
  described in <INVENTORY_PATH>. Mode: READ-ONLY.

  Your expertise: JS/TS security-first, ES2025. AI-generated JS has 2.74×
  more vulnerabilities than human-written (Veracode 2025).

  Categories:

  A) XSS / DOM safety (each with user input = P0/P1):
     innerHTML / outerHTML / insertAdjacentHTML with user input;
     document.write; dangerouslySetInnerHTML without DOMPurify; eval,
     Function(), setTimeout(string), setInterval(string); location.href
     with user input without URL validation; jQuery .html() / $(userInput).

  B) Crypto-grade randomness (each violation = P0 in auth/token paths):
     Math.random() in functions whose names suggest password / token /
     id / uuid / csrf / secret / key. Replace with crypto.getRandomValues
     or crypto.randomUUID.

  C) Async correctness:
     await in loop instead of Promise.all; fire-and-forget without
     .catch / try; unhandled promise rejection; async fn without try/catch
     at boundaries; missing AbortController for long-lived fetch; race
     conditions (read-await-write on shared state).

  D) Memory leaks:
     addEventListener without removeEventListener / {signal} / AbortController
     (audit ratio: anything below 1:1 is leakage); setInterval without
     clearInterval; observers not disconnected.

  E) Concurrent fetch dedup:
     click-spammable UI ("Refresh") without inflight-promise tracking ⇒ N
     parallel requests with last-write-wins.

  F) Silent fallback in financial / rate functions:
     `return amount` when rate is missing in convertToPLN/convertToX —
     hard rule violation (see INVENTORY §9 hard-rules).

  G) npm supply chain (CRITICAL for AI-generated code):
     for every entry in dependencies and devDependencies:
       curl -sf https://registry.npmjs.org/<pkg> >/dev/null && OK || GHOST
     packages <30 days old, <1000 weekly downloads, unknown author,
     near-typo of popular package names = P0 slopsquatting risk.
     Missing lockfile or out-of-sync = P1. Missing `npm ci` in CI = P2.

  H) Project supply policy:
     read INVENTORY §9 hard-rules for "no CDN" / "vendor only" policies.
     <script src="https://unpkg.com/...">, <link href="https://cdn..."> in
     PWA / app manifests, @import url('https://fonts.googleapis.com/...')
     in CSS — flag all of them when policy says local-only.

  I) Modern JS / deprecated:
     var (each occurrence in production code), == with user input, callbacks
     instead of async/await, jQuery 1.x/2.x in new code, XMLHttpRequest as
     request, new Buffer(size).

  J) CSP, SRI, security headers:
     missing Content-Security-Policy in response; <script src="https://...">
     without integrity= and crossorigin; inline scripts without nonce.

  K) AI anti-patterns specific to JS:
     hallucinated npm packages (verify ALL); fake API endpoints
     (cross-check with integration documentation); invented DOM/jQuery
     methods; outdated React / Vue patterns.

  Tools:
     npx eslint --ext .js,.mjs,.ts,.tsx --format json .
     npm audit --json
     npx semgrep --config=p/javascript --config=p/xss --json
     npx depcheck --json

  Output: audit/findings/03-js-deep.md, format from SKILL.md §7. Prefix: JS-.

  Rule (from your system prompt): never recommend an npm package you have
  not verified exists.
```
