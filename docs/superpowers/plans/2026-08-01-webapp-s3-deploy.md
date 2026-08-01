# Web App S3 + CloudFront Deploy Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually-triggered GitHub Actions workflow that builds the Vue web app, uploads the single self-contained `index.html` to `s3://nfcarchiver.com/banana/`, invalidates CloudFront, verifies the live site serves that exact build, and rolls back automatically if it does not.

**Architecture:** Two jobs. An uncredentialed `build` job runs `yarn install` (third-party code) and produces two artifacts: the deployable file and a compiled healthcheck script. A credentialed `deploy` job assumes an AWS role via OIDC, uploads bytes from the artifact, invalidates, verifies, and restores a pre-upload snapshot on failure. It never builds anything and never runs `yarn install`.

**Tech Stack:** GitHub Actions, AWS CLI v2 (preinstalled on `ubuntu-latest`), OIDC federation via `aws-actions/configure-aws-credentials`, TypeScript 4.4.3 (already a dependency), Jest + ts-jest 26 (already configured), Node 14 for the build (`.nvmrc`), Node 20 for the deploy job.

## Amendments (2026-08-01, after implementation)

This plan has been revised to match what actually shipped. Code review during
execution found four defects in the code blocks below as originally written, all
of which were transcribed faithfully before being caught:

1. **Task 2's argv guard rejected only `undefined`, not `""`.** Because
   `"".indexOf()` returns `0` for any string, an empty revision made the
   healthcheck match every possible body — reporting healthy and suppressing the
   rollback it exists to trigger. Fixed in the CLI, plus a defence-in-depth
   guard in `checkOnce` (Task 1).
2. **Task 3's inline-check regex could not match the failure it guards.** Vue
   CLI's default `publicPath` is `/`, so a failed inline emits root-relative
   `src="/js/…"`, which the original `(\./)?(js|css)/` pattern missed entirely.
3. **Task 4's Summary step interpolated `${{ github.ref_name }}` into a shell
   body** — a script-injection vector on a runner holding credentials for two
   production prefixes.
4. **Task 4's config check validated `S3_PREFIX`'s shape but not its value**, so
   a mistyped `app/` would have overwritten a different production application
   in the same bucket. The prefix is now pinned.

Two further steps were added that the original plan omitted: a `Lint deploy
scripts` step (Task 3), because `scripts/` sits outside vue-cli-service's
default lint glob and would otherwise never be linted; and two extra tests
(Task 1) covering failure accumulation and the empty-revision guard.

### Second wave: final whole-branch review, 2026-08-01

A review of the completed branch found one blocking defect and ten smaller ones.
All are fixed; the code blocks in Tasks 1, 3, 4 and 5 above are **superseded by
the shipped files** wherever they disagree.

1. **BLOCKING — the pipeline could not complete a single run.** Task 3's
   `Verify the compiled healthcheck starts` step opened with `set -uo pipefail`
   and then ran `node tools/healthcheck-cli.js` followed by `code=$?`. GitHub
   Actions invokes every `run:` body as `bash -e {0}`, and `set -uo pipefail`
   *adds* `-u` and `pipefail` without clearing the inherited `-e`. The `node`
   call exits `2` by design, so errexit aborted on that line, `code=$?` was never
   reached, and the step failed with exit 2 on **every** run. Now
   `code=0; node … || code=$?`. Audited every other `run:` block for the same
   class of bug; this was the only instance.
2. **A slow invalidation reverted a good build.** `aws cloudfront wait
   invalidation-completed` exits non-zero at ~10 minutes; under `set -e` that
   fired `failure()` and rolled back a perfectly good deploy. The wait (in both
   the forward and the rollback step) is now wrapped in an `if` and logs a
   warning on timeout. The object is served `no-cache`, so edges revalidate
   against S3 regardless, and the healthcheck's own ~62 s retry is the real
   arbiter. A failure of `create-invalidation` itself is still fatal.
3. **`SITE_BASE_URL` could silently point at the sibling app.** It was only
   checked non-empty. The config step now asserts it is an `https://` URL ending
   in `/${PREFIX}`, so a value like `https://nfcarchiver.com/app/` fails closed
   instead of causing every deploy to healthcheck the other application's page,
   fail, and roll `banana/` back.
4. **The documented rollback drill was the trap in (3).** Both the spec and this
   plan told the operator to temporarily repoint `SITE_BASE_URL` at
   `https://nfcarchiver.com/app/`; a forgotten reset would have rolled back every
   later deploy, silently, with an error naming CloudFront rather than the
   variable. Replaced by a `force_fail_verify` dispatch input that deploys for
   real and then verifies against an impossible revision. The drill text in the
   spec, this plan, `README.md` and `CLAUDE.md` is updated.
5. **The revision fallback reintroduced a known-bad needle.** The step fell back
   to `git rev-parse --short HEAD`, a bare 7-hex string — precisely the shape
   that forced nfcarchiver to invent a synthetic build marker, because it
   collides with unrelated hex constants in the bundle. The workflow now fails
   loudly instead. It deliberately diverges from `vue.config.js`, which keeps its
   fallback for local development.
6. **The rollback outcome was absent from the summary** — after a red run, the
   single fact an operator most needs. The step now carries `id: rollback` and
   the table gains a `rollback` row, passed via `env:` like every other value.
7. **A dry run produced no summary at all**, its guard being
   `always() && !inputs.dry_run` — the one run whose entire purpose is to show
   the plan. The guard is now `always()`, with a `mode` row and `skipped`/`n/a`
   cells for the steps a dry run does not reach.
8. **The rollback trigger was unconstrained by any test.** Only one test called
   `healthcheck()`, and it succeeded on attempt 2, so replacing the final
   `return last;` with `return { ok: true, failures: [] };` left all 7 tests
   green while disabling rollback permanently. Added a test for the
   exhausted-attempts path and verified it against exactly that mutation; it is
   the only test that fails. Two further tests cover base-URL normalisation and a
   refused connection. **10 tests now, not 5** — the counts in the spec are
   updated.
9. **The `concurrency` comment described a safety property that does not
   exist**, claiming the group name kept the two apps from blocking each other.
   Concurrency groups are repository-scoped, so a collision with nfcarchiver was
   never possible. Corrected to state what the group actually does: serialise
   this repository's own deploys.
10. **`.gitignore` ignored a bare `/tools`** with no explanation — a name a
    future real `tools/` directory would silently inherit. Commented.
11. **The spec had drifted.** The `banana/` value pin, the `SITE_BASE_URL`
    assertion, the `Lint deploy scripts` and `Verify the compiled healthcheck
    starts` steps, and the CLI's exit code `2` were all undocumented; the
    component table said "Exit 0/1". All corrected.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md`. Read it before starting.
- **No new npm dependencies.** The healthcheck uses only Node's built-in `http`, `https`, and `url` modules. `typescript@4.4.3` and `@types/node@17.0.38` are already present.
- **GitHub Action major versions: `@v4`** for `actions/*` and `aws-actions/configure-aws-credentials`, matching every existing workflow in `.github/workflows/`. Do not bump majors as a side effect of this work.
- **No optional chaining (`?.`) or nullish coalescing (`??`)** anywhere in `scripts/` or `tests/` — use ternaries. This is a repo-wide convention recorded in `CLAUDE.md`.
- **ESLint `security/recommended` is active.** `security/detect-object-injection` fires on any array or object index that is not a literal. Legitimate indexing needs `// eslint-disable-next-line security/detect-object-injection` on the line above.
- **`tsconfig.json` has `strict: true` and `noUnusedLocals: true`.** No unused variables, no implicit `any`.
- **Never widen the IAM `sub` condition to a wildcard.** It is the entire security boundary of the OIDC trust relationship.
- **Deploy target values** (used verbatim in docs and defaults): bucket `nfcarchiver.com`, prefix `banana/`, distribution `EPIRQ7CFJKRDQ`, account `533267300952`, base URL `https://nfcarchiver.com/banana/`.
- **Branch:** all work lands on `feature/webapp-s3-deploy`, which already exists and already contains the spec commit.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/healthcheck.ts` | **Create.** Pure, side-effect-free verification logic: fetch a page, assert status/content-type/revision, retry with backoff. Exports functions only — importing it must not perform I/O or read `process.argv`. |
| `scripts/healthcheck-cli.ts` | **Create.** Trivial command-line entry point. Parses `argv`, calls the module, sets the exit code. Kept separate so the tested module has zero side effects and no `require.main` guard is needed. |
| `tests/unit/healthcheck.spec.ts` | **Create.** Exercises `scripts/healthcheck.ts` against a real local `http.createServer` stub. |
| `.github/workflows/deploy-webapp.yml` | **Create.** The pipeline. Built in two tasks: the `build` job first (independently dispatchable), then the `deploy` job. |
| `.gitignore` | **Modify.** Ignore the `site/` and `tools/` staging directories. |
| `README.md` | **Modify.** Document how to deploy and what to configure. |
| `CLAUDE.md` | **Modify.** Note the pipeline; correct the existing manual-upload deployment instructions. |

---

### Task 1: Healthcheck verification module

**Files:**
- Create: `scripts/healthcheck.ts`
- Test: `tests/unit/healthcheck.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `interface FetchedPage { status: number; contentType: string; body: string }`
  - `type Fetcher = (url: string) => Promise<FetchedPage>`
  - `interface CheckResult { ok: boolean; failures: string[] }`
  - `interface HealthcheckOptions { attempts?: number; firstDelayMs?: number; fetcher?: Fetcher; sleep?: (ms: number) => Promise<void> }`
  - `function fetchPage(url: string): Promise<FetchedPage>`
  - `function checkOnce(baseUrl: string, expectedRevision: string, fetcher?: Fetcher): Promise<CheckResult>`
  - `function healthcheck(baseUrl: string, expectedRevision: string, opts?: HealthcheckOptions): Promise<CheckResult>`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/healthcheck.spec.ts`. The `@jest-environment node` docblock **must be the first thing in the file** — this repo's Jest preset defaults to jsdom, and binding a real TCP listener belongs in the node environment.

```typescript
/**
 * @jest-environment node
 */
import * as http from "http";
import { AddressInfo } from "net";
import { checkOnce, healthcheck } from "../../scripts/healthcheck";

interface StubResponse {
  status: number;
  contentType: string;
  body: string;
}

const REVISION = "v0.9.0-3-gdeadbee";

describe("healthcheck", () => {
  let server: http.Server;
  let responses: StubResponse[];
  let hits: number;
  let baseUrl: string;

  beforeEach(async () => {
    hits = 0;
    responses = [];
    server = http.createServer((_req, res) => {
      // Serve each queued response once, then repeat the last one forever.
      const index = hits < responses.length ? hits : responses.length - 1;
      hits += 1;
      // eslint-disable-next-line security/detect-object-injection
      const stub = responses[index];
      res.writeHead(stub.status, { "Content-Type": stub.contentType });
      res.end(stub.body);
    });
    await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
    const address = server.address() as AddressInfo;
    baseUrl = "http://127.0.0.1:" + address.port + "/banana/";
  });

  afterEach(async () => {
    await new Promise<void>(resolve => server.close(() => resolve()));
  });

  it("passes when the served page carries the expected revision", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build " + REVISION + "</html>"
      }
    ];

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.failures).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it("fails when the served page carries an older revision", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build v0.8.3-4-gca75a75</html>"
      }
    ];

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain(REVISION);
  });

  it("fails on a non-200 response", async () => {
    responses = [
      { status: 403, contentType: "text/html; charset=utf-8", body: "denied" }
    ];

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain("403");
  });

  it("fails when the content type is not html", async () => {
    responses = [
      {
        status: 200,
        contentType: "application/xml",
        body: "<Error>" + REVISION + "</Error>"
      }
    ];

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain("application/xml");
  });

  it("collects every failure in one pass rather than stopping at the first", async () => {
    responses = [
      { status: 500, contentType: "application/xml", body: "<Error/>" }
    ];

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.ok).toBe(false);
    expect(result.failures.length).toBe(2);
    expect(result.failures.join(" ")).toContain("500");
    expect(result.failures.join(" ")).toContain("application/xml");
  });

  it("refuses an empty expected revision instead of matching everything", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build v0.8.3-4-gca75a75</html>"
      }
    ];

    const result = await checkOnce(baseUrl, "");

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain("empty");
    expect(hits).toBe(0);
  });

  it("retries a stale edge and passes once the new build appears", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build v0.8.3-4-gca75a75</html>"
      },
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build " + REVISION + "</html>"
      }
    ];

    const result = await healthcheck(baseUrl, REVISION, {
      attempts: 3,
      sleep: () => Promise.resolve()
    });

    expect(result.ok).toBe(true);
    expect(hits).toBe(2);
  });

  // The only test that constrains the rollback trigger. Without it, changing
  // healthcheck()'s final `return last;` to `return { ok: true, failures: [] }`
  // leaves every other test green while reporting every deploy healthy and
  // disabling rollback permanently.
  it("reports failure after exhausting every attempt", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build v0.8.3-4-gca75a75</html>"
      }
    ];

    const result = await healthcheck(baseUrl, REVISION, {
      attempts: 3,
      sleep: () => Promise.resolve()
    });

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain(REVISION);
    expect(hits).toBe(3);
  });

  it("normalises a base url with no trailing slash", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build " + REVISION + "</html>"
      }
    ];

    const noSlash = baseUrl.replace(/\/$/, "");
    const result = await checkOnce(noSlash, REVISION);

    expect(result.failures).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it("reports a connection failure rather than throwing", async () => {
    await new Promise<void>(resolve => server.close(() => resolve()));

    const result = await checkOnce(baseUrl, REVISION);

    expect(result.ok).toBe(false);
    expect(result.failures.join(" ")).toContain("failed");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn test:unit --testPathPattern=healthcheck
```

Expected: FAIL — `Cannot find module '../../scripts/healthcheck'`.

- [ ] **Step 3: Write the implementation**

Create `scripts/healthcheck.ts`:

```typescript
/**
 * Post-deploy verification. Fetches the live site through its PUBLIC url — so
 * DNS, CloudFront and S3 are all exercised, not just the origin — and asserts
 * it is serving the build this run produced.
 *
 * A 200 only proves S3 holds something. The revision match is the load-bearing
 * check: it proves the page is THIS build and that no edge is still serving the
 * previous one.
 *
 * Uses Node's http/https modules rather than global fetch so that this repo's
 * Node 14 Jest run exercises the same code path that runs in production.
 *
 * This module is side-effect free and never reads process.argv; the command
 * line entry point lives in healthcheck-cli.ts.
 */
import * as http from "http";
import * as https from "https";
import { URL } from "url";

export interface FetchedPage {
  status: number;
  contentType: string;
  body: string;
}

// eslint-disable-next-line no-unused-vars
export type Fetcher = (url: string) => Promise<FetchedPage>;

export interface CheckResult {
  ok: boolean;
  failures: string[];
}

export interface HealthcheckOptions {
  attempts?: number;
  firstDelayMs?: number;
  fetcher?: Fetcher;
  // eslint-disable-next-line no-unused-vars
  sleep?: (ms: number) => Promise<void>;
}

const REQUEST_TIMEOUT_MS = 30000;

/** Redirects are deliberately NOT followed: the deploy target is a directory
 *  URL that must resolve to index.html at the edge, so a 301 here is a real
 *  finding about CloudFront configuration, not something to paper over. */
export function fetchPage(url: string): Promise<FetchedPage> {
  return new Promise<FetchedPage>((resolve, reject) => {
    const target = new URL(url);
    const client = target.protocol === "https:" ? https : http;
    const request = client.get(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port,
        path: target.pathname + target.search,
        headers: { "cache-control": "no-cache", pragma: "no-cache" }
      },
      response => {
        let body = "";
        response.setEncoding("utf8");
        response.on("data", chunk => {
          body += chunk;
        });
        response.on("end", () => {
          const header = response.headers["content-type"];
          resolve({
            status: response.statusCode === undefined ? 0 : response.statusCode,
            contentType: header === undefined ? "" : String(header),
            body
          });
        });
      }
    );
    request.on("error", reject);
    request.setTimeout(REQUEST_TIMEOUT_MS, () => {
      request.destroy(new Error("request timed out after " + REQUEST_TIMEOUT_MS + "ms"));
    });
  });
}

/** One full pass. Collects every failure rather than stopping at the first, so
 *  a failing deploy reports everything wrong with it in one log. */
export async function checkOnce(
  baseUrl: string,
  expectedRevision: string,
  fetcher: Fetcher = fetchPage
): Promise<CheckResult> {
  // An empty revision would match every possible body: "".indexOf() returns 0
  // for any string, so the check below could never fail and the healthcheck
  // would wave through any deploy. Refuse before issuing a request.
  if (expectedRevision === "") {
    return { ok: false, failures: ["expectedRevision is empty — refusing to treat any response as a match"] };
  }

  const base = baseUrl.endsWith("/") ? baseUrl : baseUrl + "/";

  let page: FetchedPage;
  try {
    page = await fetcher(base);
  } catch (error) {
    return { ok: false, failures: ["GET " + base + " failed: " + String(error)] };
  }

  const failures: string[] = [];
  if (page.status !== 200) {
    failures.push("GET " + base + " -> " + page.status + " (want 200)");
  }
  if (!page.contentType.startsWith("text/html")) {
    failures.push('GET ' + base + ' content-type "' + page.contentType + '" (want text/html)');
  }
  if (page.status === 200 && page.body.indexOf(expectedRevision) === -1) {
    failures.push(
      "served page does not contain the build revision " +
        expectedRevision +
        " — an older version is still live"
    );
  }

  return { ok: failures.length === 0, failures };
}

function defaultSleep(ms: number): Promise<void> {
  return new Promise<void>(resolve => setTimeout(resolve, ms));
}

/** Retry with exponential backoff to absorb residual CloudFront propagation.
 *  Defaults to ~62s across 6 attempts (2s, 4s, 8s, 16s, 32s). */
export async function healthcheck(
  baseUrl: string,
  expectedRevision: string,
  opts: HealthcheckOptions = {}
): Promise<CheckResult> {
  const attempts = opts.attempts === undefined ? 6 : opts.attempts;
  const fetcher = opts.fetcher === undefined ? fetchPage : opts.fetcher;
  const sleep = opts.sleep === undefined ? defaultSleep : opts.sleep;
  let delay = opts.firstDelayMs === undefined ? 2000 : opts.firstDelayMs;
  let last: CheckResult = { ok: false, failures: ["no attempt was made"] };

  for (let attempt = 1; attempt <= attempts; attempt++) {
    last = await checkOnce(baseUrl, expectedRevision, fetcher);
    if (last.ok) {
      return last;
    }
    if (attempt < attempts) {
      // eslint-disable-next-line no-console
      console.error("attempt " + attempt + "/" + attempts + " failed:");
      // eslint-disable-next-line no-console
      last.failures.forEach(failure => console.error("  - " + failure));
      // eslint-disable-next-line no-console
      console.error("retrying in " + delay + "ms");
      await sleep(delay);
      delay *= 2;
    }
  }

  return last;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn test:unit --testPathPattern=healthcheck
```

Expected: PASS — 10 passed.

- [ ] **Step 5: Run lint and the full suite**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn lint --max-warnings 0 && yarn test:unit
```

Expected: both clean. If `security/detect-object-injection` fires on `responses[index]` in the test, confirm the `eslint-disable-next-line` comment from Step 1 is on the line immediately above it.

- [ ] **Step 6: Commit**

```bash
git add scripts/healthcheck.ts tests/unit/healthcheck.spec.ts
git commit -m "feat: add post-deploy healthcheck verification module

Asserts a live URL returns 200, text/html, and a body containing the
expected build revision. Retries with exponential backoff to absorb
CloudFront propagation.

Uses node http/https rather than global fetch so the Node 14 Jest run
exercises the same code path that runs in production, against a real
local server stub."
```

---

### Task 2: Command-line entry point

**Files:**
- Create: `scripts/healthcheck-cli.ts`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `healthcheck(baseUrl, expectedRevision, opts?)` from `scripts/healthcheck.ts` (Task 1). Its resolved `CheckResult` supplies `.ok: boolean` and `.failures: string[]`.
- Produces: a compiled `tools/healthcheck-cli.js` invoked as `node tools/healthcheck-cli.js <baseUrl> <expectedRevision>`. Exit codes: `0` healthy, `1` unhealthy, `2` bad usage.

- [ ] **Step 1: Write the entry point**

Create `scripts/healthcheck-cli.ts`:

```typescript
/**
 * Command line wrapper around healthcheck.ts.
 *
 *   node tools/healthcheck-cli.js https://nfcarchiver.com/banana/ v0.8.3-4-gca75a75
 *
 * Exit codes: 0 healthy, 1 unhealthy, 2 bad usage. The deploy workflow treats a
 * non-zero exit as the trigger to roll back, so the split between 1 and 2
 * matters: 2 means the workflow invoked this wrong, not that the site is bad.
 *
 * Kept separate from healthcheck.ts so that module stays side-effect free and
 * can be imported by tests without argv parsing or process.exit running.
 */
import { healthcheck } from "./healthcheck";

const args = process.argv.slice(2);
const baseUrl = args[0];
const expectedRevision = args[1];

// Empty strings must be rejected, not just undefined. An unset workflow
// variable arrives as "", and an empty expectedRevision would make checkOnce
// match every possible body — reporting healthy and suppressing the rollback
// this CLI exists to trigger.
if (
  baseUrl === undefined ||
  baseUrl === "" ||
  expectedRevision === undefined ||
  expectedRevision === ""
) {
  // eslint-disable-next-line no-console
  console.error("usage: node healthcheck-cli.js <baseUrl> <expectedRevision>");
  process.exit(2);
}

// Chained .then().catch() rather than the two-argument .then(ok, err) form:
// the two-argument form does not catch exceptions thrown inside its own
// success handler, and the two Node versions this repo straddles disagree
// about what an unhandled rejection means (Node 14 warns and exits 0 —
// reporting "healthy"; Node 20 exits 1).
//
// process.exitCode rather than process.exit(): calling exit() immediately
// after console output can truncate it on the non-blocking piped streams a CI
// runner uses, and the dropped lines would be the rollback diagnostics.
healthcheck(baseUrl, expectedRevision)
  .then(result => {
    if (result.ok) {
      // eslint-disable-next-line no-console
      console.log("healthy: " + baseUrl + " is serving build " + expectedRevision);
      process.exitCode = 0;
      return;
    }
    // eslint-disable-next-line no-console
    console.error("UNHEALTHY:");
    // eslint-disable-next-line no-console
    result.failures.forEach(failure => console.error("  - " + failure));
    process.exitCode = 1;
  })
  .catch(error => {
    // eslint-disable-next-line no-console
    console.error("healthcheck crashed: " + String(error));
    process.exitCode = 1;
  });
```

- [ ] **Step 2: Ignore the staging directories**

Add to `.gitignore`, after the existing `/dist` line:

```gitignore
# Deploy pipeline staging directories, both build output of
# .github/workflows/deploy-webapp.yml:
#   /site   — the single dist/index.html staged for upload
#   /tools  — the compiled healthcheck (tsc output of scripts/healthcheck*.ts)
# `/tools` is a generic name. If a real, source-controlled tools/ directory is
# ever added to this repo it would be silently ignored by this line — change
# the compiler's --outDir instead of deleting the rule.
/site
/tools
```

- [ ] **Step 3: Compile it the way the workflow will**

The explicit file list makes `tsc` ignore `tsconfig.json` entirely — which is what we want, since the project config sets `"module": "esnext"`, wrong for a Node CLI.

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && \
npx tsc scripts/healthcheck.ts scripts/healthcheck-cli.ts \
  --outDir tools --module commonjs --target es2019 \
  --strict --esModuleInterop --skipLibCheck
```

Expected: no output, and `tools/healthcheck.js` + `tools/healthcheck-cli.js` now exist.

- [ ] **Step 4: Verify the compiled output actually runs**

```bash
node tools/healthcheck-cli.js; echo "exit=$?"
```

Expected: prints the usage line and `exit=2`. This proves the compiled artifact loads under Node before the credentialed job depends on it.

- [ ] **Step 5: Verify it detects a bad deploy end to end**

```bash
node tools/healthcheck-cli.js https://example.com/ v0.0.0-0-gnope; echo "exit=$?"
```

Expected: retries with visible backoff, then `UNHEALTHY:` naming the missing revision, and `exit=1`. This takes ~62 s; that is the real backoff schedule and confirms it.

- [ ] **Step 6: Commit**

```bash
git add scripts/healthcheck-cli.ts .gitignore
git commit -m "feat: add healthcheck command line entry point

Separate from healthcheck.ts so the tested module stays side-effect
free. Exit 2 for bad usage is distinct from exit 1 for an unhealthy
site, so the workflow can tell 'we invoked this wrong' from 'roll back'."
```

---

### Task 3: Workflow — build job

**Files:**
- Create: `.github/workflows/deploy-webapp.yml`

**Interfaces:**
- Consumes: `scripts/healthcheck.ts` and `scripts/healthcheck-cli.ts` (Tasks 1–2).
- Produces: job output `needs.build.outputs.revision` (the `git describe` string), artifact `site` (containing `index.html`), artifact `deploy-tools` (containing `healthcheck.js` and `healthcheck-cli.js`). Task 4 consumes all three.

- [ ] **Step 1: Write the workflow with the build job only**

Create `.github/workflows/deploy-webapp.yml`. This is dispatchable and testable on its own — it builds, verifies, and uploads artifacts, with no AWS involvement at all.

```yaml
name: Deploy web app

# Manual only. Never on push or tag.
on:
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Print the S3 upload plan and stop — uploads nothing'
        type: boolean
        default: false
      force_fail_verify:
        description: 'Deploy for real, then force verification to fail — exercises the rollback path'
        type: boolean
        default: false

# No ambient permissions anywhere. The deploy job opts in to id-token below.
permissions: {}

concurrency:
  # Queue, never cancel: a run cancelled mid-deploy could strand the prefix.
  # This serialises THIS repository's own deploys against each other, so two
  # dispatches cannot interleave a snapshot with another run's upload.
  # It offers no protection against the sibling app that shares this bucket:
  # concurrency groups are scoped to a repository, so nfcarchiver's runs were
  # never in this group's scope regardless of what it is named.
  group: deploy-banana-webapp
  cancel-in-progress: false

jobs:
  build:
    name: Build & verify bundle
    runs-on: ubuntu-latest
    # This job runs `yarn install`, which executes third-party package code. It
    # holds no AWS credential, so a compromised dependency cannot reach S3.
    permissions: {}
    outputs:
      revision: ${{ steps.stamp.outputs.revision }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          # Tags are REQUIRED. vue.config.js:7-12 stamps the build with
          # `git describe --long --tags` and falls back to a short SHA when it
          # throws. A shallow clone has no tags, so the fallback would fire and
          # the build would carry a different string than this workflow expects.
          fetch-depth: 0

      - name: Read .nvmrc
        run: echo "NVMRC=$(cat .nvmrc)" >> $GITHUB_ENV

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NVMRC }}
          cache: 'yarn'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Lint
        run: yarn lint --max-warnings 0

      - name: Lint deploy scripts
        # `yarn lint` uses vue-cli-service's default glob (src, tests, *.js),
        # which does not include scripts/. Without this step the code that
        # gates a production rollback is never linted.
        run: yarn lint --no-fix --max-warnings 0 scripts/healthcheck.ts scripts/healthcheck-cli.ts

      - name: Unit tests
        run: yarn test:unit

      - name: Compute build revision
        id: stamp
        # Mirrors vue.config.js:7-12, but WITHOUT its short-SHA fallback, and
        # that divergence is deliberate. vue.config.js keeps the fallback so a
        # local `yarn build` works in a clone with no tags. This workflow must
        # refuse what local development may tolerate: a bare 7-hex-character
        # needle can occur by coincidence inside the 1.2 MB bundle, and the
        # healthcheck's `indexOf` would then match an unrelated hex run and wave
        # a stale deploy through. `git describe --long --tags` output has a
        # `vN.N.N-N-g<sha>` shape that cannot occur by accident, so it is the
        # only safe needle. If there is no reachable tag, we stop.
        run: |
          set -euo pipefail
          if ! revision="$(git describe --long --tags 2>/dev/null)"; then
            echo "::error::git describe --long --tags failed — no reachable tag. Refusing to deploy: the fallback short SHA is a 7-hex needle that can collide with unrelated constants in the bundle and wave a stale deploy through. Fetch tags, or deploy from a ref with an ancestor tag."
            exit 1
          fi
          echo "revision=${revision}" >> "$GITHUB_OUTPUT"
          echo "build revision: ${revision}"

      - name: Build
        run: yarn build

      - name: Verify the bundle
        env:
          REVISION: ${{ steps.stamp.outputs.revision }}
        # Three checks, all while no credential is in scope and nothing has been
        # touched. Check 3 is load-bearing: if html-webpack-inline-source-plugin
        # ever silently stops inlining, the build still "succeeds" but emits an
        # index.html referencing dist/js/*.js — files this workflow deliberately
        # does not upload — and production would serve a blank page. The pattern
        # must match root-relative paths (src="/js/...") too, since Vue CLI's
        # default publicPath is "/" — a bare "js/" or "./js/" prefix is not the
        # only shape a failed inline can take.
        run: |
          set -euo pipefail
          f=dist/index.html
          [ -s "$f" ] || { echo "::error::$f is missing or empty"; exit 1; }

          grep -qF "$REVISION" "$f" || {
            echo "::error::$f does not contain revision ${REVISION} — either DefinePlugin did not run, or this workflow and vue.config.js disagree about the revision"
            exit 1
          }

          if grep -qE '(src|href)="[^"]*\.(js|css)"' "$f"; then
            echo "::error::$f references external assets — the inline-source plugin did not inline them"
            grep -oE '(src|href)="[^"]*\.(js|css)"' "$f" | sort -u
            exit 1
          fi

          echo "bundle ok: $(wc -c < "$f") bytes, revision ${REVISION}, fully inlined"

      - name: Stage the deployable file
        # ONLY index.html. `yarn build` also emits dist/js/*.js (~1.2 MB), which
        # the plugin has already inlined into the HTML; uploading them would
        # publish dead bundles at /banana/js/.
        run: |
          set -euo pipefail
          mkdir -p site
          cp dist/index.html site/index.html

      - name: Compile the healthcheck
        # Explicit file list, so tsc ignores tsconfig.json — the project sets
        # "module": "esnext", which is wrong for a Node CLI.
        run: |
          set -euo pipefail
          npx tsc scripts/healthcheck.ts scripts/healthcheck-cli.ts \
            --outDir tools --module commonjs --target es2019 \
            --strict --esModuleInterop --skipLibCheck

      - name: Verify the compiled healthcheck starts
        # Proves the artifact loads under Node before the credentialed job
        # depends on it. Bad usage must exit 2.
        #
        # The `|| code=$?` form is REQUIRED, not stylistic. GitHub Actions runs
        # every `run:` body as `bash -e {0}`, so errexit is already on before
        # the first line executes, and `set -uo pipefail` cannot remove it — it
        # only adds -u and pipefail. This step originally shipped as a bare
        # `node ...` followed by `code=$?`; because the node call exits 2 BY
        # DESIGN, errexit aborted the script at that line, `code=$?` was never
        # reached, and the step failed with exit 2 on every single run. Do not
        # "simplify" this back.
        run: |
          set -uo pipefail
          code=0
          node tools/healthcheck-cli.js >/dev/null 2>&1 || code=$?
          if [ "$code" -ne 2 ]; then
            echo "::error::compiled healthcheck did not start correctly (exit ${code}, want 2)"
            exit 1
          fi
          echo "healthcheck binary ok"

      - name: Upload deployable site
        uses: actions/upload-artifact@v4
        with:
          name: site
          path: site/
          if-no-files-found: error
          retention-days: 7

      - name: Upload healthcheck tool
        # Shipped as its own artifact so the credentialed job can verify the
        # deploy without checking out the repo or running `yarn install`.
        uses: actions/upload-artifact@v4
        with:
          name: deploy-tools
          path: tools/
          if-no-files-found: error
          retention-days: 7
```

- [ ] **Step 2: Validate the YAML parses**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/deploy-webapp.yml')); print('yaml ok')"
```

Expected: `yaml ok`.

- [ ] **Step 3: Reproduce the build job's checks locally**

Confirms the three bundle checks pass against a real build before relying on them in CI.

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn build && \
REVISION="$(git describe --long --tags)" && \
f=dist/index.html && \
[ -s "$f" ] && echo "non-empty ok" && \
grep -qF "$REVISION" "$f" && echo "revision ${REVISION} present" && \
! grep -qE '(src|href)="[^"]*\.(js|css)"' "$f" && echo "fully inlined ok"
```

Expected: `non-empty ok`, `revision <something> present`, `fully inlined ok`.

A passing run proves only that the check does not *false-fail* on a good build.
To prove it can actually catch a broken one, temporarily disable `inlineSource`
in `vue.config.js`, rebuild, confirm the same `grep` now matches
`src="/js/chunk-vendors.*.js"`, then restore `vue.config.js` and rebuild. The
original version of this check passed both directions of that test only by
accident — it matched nothing either way.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy-webapp.yml
git commit -m "feat: add deploy workflow build job

Uncredentialed job: lint, test, build, then three bundle sanity checks
(non-empty, carries the git-describe revision, fully inlined). Stages
only dist/index.html — dist/js/*.js is dead output the inline plugin has
already folded into the HTML.

fetch-depth: 0 is required; without tags vue.config.js falls back to a
short SHA and the healthcheck would look for the wrong string."
```

---

### Task 4: Workflow — deploy job

**Files:**
- Modify: `.github/workflows/deploy-webapp.yml` (append the `deploy` job)

**Interfaces:**
- Consumes: `needs.build.outputs.revision`, artifacts `site` and `deploy-tools` (Task 3); `node tools/healthcheck-cli.js <baseUrl> <expectedRevision>` (Task 2).
- Produces: the deployed object and a run summary. Nothing downstream consumes it.

- [ ] **Step 1: Append the deploy job**

Add to `.github/workflows/deploy-webapp.yml`, at the same indentation as `build:`:

```yaml
  deploy:
    name: Deploy to S3 + CloudFront
    needs: build
    runs-on: ubuntu-latest
    # Zero required reviewers — this exists to pin the OIDC trust policy on
    # `environment:production` and to restrict deploys to master.
    environment: production
    permissions:
      id-token: write   # mint the OIDC token used to assume the AWS role
      contents: read
    env:
      BUCKET: ${{ vars.S3_BUCKET }}
      PREFIX: ${{ vars.S3_PREFIX }}
      DIST_ID: ${{ vars.CLOUDFRONT_DISTRIBUTION_ID }}
      BASE_URL: ${{ vars.SITE_BASE_URL }}
      REVISION: ${{ needs.build.outputs.revision }}
    steps:
      - name: Download deployable site
        uses: actions/download-artifact@v4
        with:
          name: site
          path: site

      - name: Download healthcheck tool
        uses: actions/download-artifact@v4
        with:
          name: deploy-tools
          path: tools

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Check configuration is present
        # Fail loudly and early rather than letting an empty variable turn into
        # `s3:///` or a masked-out path deep in an upload command.
        run: |
          set -euo pipefail
          missing=0
          for v in BUCKET PREFIX DIST_ID BASE_URL REVISION; do
            if [ -z "${!v:-}" ]; then
              echo "::error::$v is empty — check the repository variables"
              missing=1
            fi
          done
          case "${PREFIX}" in
            */) ;;
            *) echo "::error::S3_PREFIX must end with a slash (got '${PREFIX}')"; missing=1 ;;
          esac
          case "${PREFIX}" in
            banana/) ;;
            *) echo "::error::refusing to deploy to prefix '${PREFIX}' — this workflow only deploys to banana/"; missing=1 ;;
          esac
          # SITE_BASE_URL must name the prefix this run actually deploys to.
          # If it points anywhere else — most plausibly the sibling app at
          # /app/, which returns 200 and text/html — every deploy would upload
          # to banana/, healthcheck a page that can never carry this revision,
          # fail, and roll banana/ back. Silently, run after run, with an error
          # naming CloudFront rather than the variable.
          case "${BASE_URL}" in
            https://*/"${PREFIX}") ;;
            *) echo "::error::SITE_BASE_URL ('${BASE_URL}') must be an https URL ending in '/${PREFIX}' — otherwise the healthcheck verifies a different page than the one this run deployed"; missing=1 ;;
          esac
          [ "$missing" -eq 0 ] || exit 1
          echo "target s3://${BUCKET}/${PREFIX} | distribution ${DIST_ID} | build ${REVISION}"

      - name: Assume the AWS deploy role via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          role-session-name: gha-banana-deploy-${{ github.run_id }}

      - name: Show what would be uploaded, then stop
        if: ${{ inputs.dry_run }}
        run: |
          set -euo pipefail
          aws s3 cp ./site/index.html "s3://${BUCKET}/${PREFIX}index.html" --dryrun \
            --content-type 'text/html; charset=utf-8' \
            --cache-control 'no-cache'
          echo "dry_run: nothing was uploaded."

      - name: Snapshot the live file for rollback
        id: snapshot
        if: ${{ !inputs.dry_run }}
        # `sync` rather than `cp`: a first deploy against an empty prefix must
        # succeed, not error on a missing key.
        run: |
          set -euo pipefail
          mkdir -p previous
          aws s3 sync "s3://${BUCKET}/${PREFIX}" ./previous/ --exclude '*' --include 'index.html'
          if [ -f ./previous/index.html ]; then
            echo "captured=true" >> "$GITHUB_OUTPUT"
            echo "snapshot: $(wc -c < ./previous/index.html) bytes"
          else
            echo "captured=false" >> "$GITHUB_OUTPUT"
            echo "no object at s3://${BUCKET}/${PREFIX}index.html — first deploy, nothing to roll back to"
          fi

      - name: Upload the page
        id: upload
        if: ${{ !inputs.dry_run }}
        # One object, fixed key. No --delete: it has no work to do here and
        # would only add blast radius on a bucket shared with another app.
        # Content type explicit — S3's guessing is not trusted.
        run: |
          set -euo pipefail
          aws s3 cp ./site/index.html "s3://${BUCKET}/${PREFIX}index.html" \
            --content-type 'text/html; charset=utf-8' \
            --cache-control 'no-cache'

      - name: Invalidate the prefix and wait
        id: invalidate
        if: ${{ !inputs.dry_run }}
        run: |
          set -euo pipefail
          id=$(aws cloudfront create-invalidation \
                 --distribution-id "${DIST_ID}" \
                 --paths "/${PREFIX}*" \
                 --query 'Invalidation.Id' --output text)
          echo "invalidation=${id}" >> "$GITHUB_OUTPUT"
          echo "created invalidation ${id} for /${PREFIX}*"
          # Wait so the healthcheck does not test a stale edge copy — but a
          # slow wait must NOT fail the step. `aws cloudfront wait` polls
          # 20s x 30 and exits non-zero at ~10 minutes; under `set -e` that
          # would fire failure(), and rollback would overwrite a perfectly good
          # deploy on nothing worse than a slow invalidation. The healthcheck
          # is the real arbiter, and it retries ~62s of its own.
          if aws cloudfront wait invalidation-completed \
               --distribution-id "${DIST_ID}" --id "${id}"; then
            echo "invalidation ${id} completed"
          else
            echo "::warning::invalidation ${id} did not complete within the CLI wait cap; continuing to the healthcheck, which is the real arbiter. The object is served no-cache, so edges revalidate against S3 regardless."
          fi

      - name: Verify the live site serves this build
        id: verify
        if: ${{ !inputs.dry_run }}
        # force_fail_verify exists so the rollback path can be exercised
        # deliberately, without repointing SITE_BASE_URL at another application.
        # (Repointing it is now refused by the config check anyway, and if the
        # operator forgot to set it back every later deploy would roll itself
        # back.) The forced run still takes ~62s — that is the CLI's real
        # backoff schedule, and it is intended.
        run: |
          set -euo pipefail
          if [ "${FORCE_FAIL}" = "true" ]; then
            echo "::warning::force_fail_verify is set — using a revision that cannot match, to exercise rollback"
            node tools/healthcheck-cli.js "${BASE_URL}" "force-fail-verify-no-such-revision"
          else
            node tools/healthcheck-cli.js "${BASE_URL}" "${REVISION}"
          fi
        env:
          FORCE_FAIL: ${{ inputs.force_fail_verify }}

      - name: Roll back to the previous version
        id: rollback
        # Runs only when something after the snapshot failed. Guarded on the
        # snapshot having actually captured a file — on a first deploy there is
        # nothing to restore — and on the upload having been attempted.
        if: ${{ failure() && !inputs.dry_run && steps.snapshot.outputs.captured == 'true' && steps.upload.outcome != 'skipped' }}
        run: |
          set -euo pipefail
          echo "::error::Deploy verification failed — restoring the previous version."
          aws s3 cp ./previous/index.html "s3://${BUCKET}/${PREFIX}index.html" \
            --content-type 'text/html; charset=utf-8' \
            --cache-control 'no-cache'
          rollback_id=$(aws cloudfront create-invalidation \
                          --distribution-id "${DIST_ID}" \
                          --paths "/${PREFIX}*" \
                          --query 'Invalidation.Id' --output text)
          # Same treatment as the forward invalidation: the restore itself has
          # already succeeded by this point, so a slow invalidation must not
          # report the rollback as failed.
          if aws cloudfront wait invalidation-completed \
               --distribution-id "${DIST_ID}" --id "${rollback_id}"; then
            echo "rolled back; invalidation ${rollback_id} completed"
          else
            echo "::warning::rolled back, but invalidation ${rollback_id} did not complete within the CLI wait cap. The restored object is served no-cache, so edges revalidate against S3 regardless."
          fi

      - name: Report that rollback was not possible
        if: ${{ failure() && !inputs.dry_run && steps.snapshot.outputs.captured != 'true' && steps.upload.outcome != 'skipped' }}
        # Via env:, like every other value in this file — the step outcome is a
        # GitHub-controlled enum rather than attacker input, but the rule that
        # nothing is interpolated into a run body on a credentialed runner is
        # worth keeping exceptionless.
        env:
          UPLOAD: ${{ steps.upload.outcome }}
        run: |
          if [ "${UPLOAD}" = "success" ]; then
            echo "::error::Deploy failed and there was no previous version to restore (first deploy). The prefix now holds build ${REVISION}, unverified."
          else
            echo "::error::Deploy failed before the upload completed and there was no previous version to restore (first deploy). The prefix may hold nothing."
          fi

      - name: Summary
        # `always()` with no dry_run condition: a dry run is precisely the run
        # whose purpose is to show the plan, so it must produce a summary too.
        # On a dry run the invalidate/verify/rollback steps are skipped, so
        # their cells read `skipped`/`n/a` — which is the correct and
        # informative answer, not a gap.
        #
        # Values reach the script through env:, never by interpolating ${{ }}
        # into the body. github.ref_name is attacker-influenced — git permits
        # `$`, `(` and `)` in ref names — and this step runs with if: always()
        # on a runner holding credentials for two production prefixes.
        if: ${{ always() }}
        env:
          REF: ${{ github.ref_name }}
          MODE: ${{ inputs.dry_run && 'dry run (nothing uploaded)' || 'deploy' }}
          INVALIDATION: ${{ steps.invalidate.outputs.invalidation }}
          VERIFY: ${{ steps.verify.outcome }}
          ROLLBACK: ${{ steps.rollback.outcome }}
        run: |
          {
            echo "### Banana Split web app deploy"
            echo ""
            echo "| field | value |"
            echo "|---|---|"
            echo "| mode | ${MODE} |"
            echo "| build | \`${REVISION}\` |"
            echo "| ref | \`${REF}\` |"
            echo "| target | \`s3://${BUCKET}/${PREFIX}index.html\` |"
            echo "| url | ${BASE_URL} |"
            echo "| invalidation | \`${INVALIDATION:-n/a}\` |"
            echo "| verify | ${VERIFY:-did not run} |"
            echo "| rollback | ${ROLLBACK:-did not run} |"
          } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 2: Validate the YAML parses and both jobs are present**

```bash
python3 -c "
import yaml
w = yaml.safe_load(open('.github/workflows/deploy-webapp.yml'))
assert list(w['jobs']) == ['build', 'deploy'], list(w['jobs'])
assert w['jobs']['deploy']['environment'] == 'production'
assert w['jobs']['deploy']['permissions']['id-token'] == 'write'
assert w['jobs']['build']['permissions'] == {}
print('workflow ok')
"
```

Expected: `workflow ok`.

- [ ] **Step 3: Confirm no `--delete` and no unscoped invalidation slipped in**

```bash
! grep -n -- '--delete' .github/workflows/deploy-webapp.yml && echo "no --delete: ok"
! grep -nE -- '--paths "/\*"' .github/workflows/deploy-webapp.yml && echo "no unscoped invalidation: ok"
```

Expected: both `ok` lines.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy-webapp.yml
git commit -m "feat: add deploy workflow S3 + CloudFront job

Credentialed job via OIDC: snapshot, upload, invalidate and wait, then
healthcheck through the public domain. Restores the snapshot and fails
loudly if invalidation or verification fails.

No --delete: one object with a fixed key on a bucket shared with another
app, so --delete has no work to do and only adds blast radius."
```

---

### Task 5: Documentation and operator setup

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the whole pipeline (Tasks 1–4).
- Produces: nothing consumed by code.

- [ ] **Step 1: Document the pipeline in `README.md`**

Append this section to `README.md`:

````markdown
## Deploying the Web App

The web app is deployed to `https://nfcarchiver.com/banana/` by the
**Deploy web app** workflow (`.github/workflows/deploy-webapp.yml`). It is
**manual only** — it never runs on push or tag.

Actions → Deploy web app → Run workflow. Pick a ref, then optionally tick either
input:

| Input | Effect |
|---|---|
| `dry_run` | Print the upload plan and stop. Uploads nothing. |
| `force_fail_verify` | Deploy for real, then force verification to fail, exercising the rollback path. Takes ~62 s at the verify step — that is the healthcheck's real backoff schedule. |

The ref must have a reachable tag: the workflow stamps the build with
`git describe --long --tags` and **refuses to deploy** if that fails, rather than
falling back to a short SHA that could collide with unrelated hex in the bundle.

The workflow builds and verifies the bundle in a job with no AWS access, then
uploads, invalidates CloudFront, and checks that the live URL serves the exact
build it produced. If that check fails it restores the previous version
automatically and fails the run.

### One-Time Setup

**Repository → Settings → Secrets and variables → Actions**

| Kind | Name | Value |
|---|---|---|
| Secret | `AWS_DEPLOY_ROLE_ARN` | the deploy role ARN (secret, so the account ID is masked in logs) |
| Variable | `AWS_REGION` | the bucket's region |
| Variable | `S3_BUCKET` | `nfcarchiver.com` |
| Variable | `S3_PREFIX` | `banana/` — the workflow refuses to run for any other value, since the deploy role can also write to the sibling app's `app/` prefix in the same bucket. Changing the deploy target requires editing the workflow, not just this variable. |
| Variable | `CLOUDFRONT_DISTRIBUTION_ID` | `EPIRQ7CFJKRDQ` |
| Variable | `SITE_BASE_URL` | `https://nfcarchiver.com/banana/` |

**Repository → Settings → Environments → New environment `production`**
Required reviewers: **none**. Deployment branches: **selected branches → `master`**.

**AWS.** The OIDC provider and the deploy role already exist, shared with the
`nfcarchiver` repository. Both of the role's policies need updating — the exact
JSON is in
[`docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md`](docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md),
section *AWS setup*. In short: the trust policy's `sub` condition gains
`repo:mezinster/banana_split:environment:production`, and the permission policy
gains the `banana/` prefix for objects and for `ListBucket`.

### Before the First Real Deploy

Two things live outside the role's policy and will produce a successful-looking
deploy that serves a broken page. Check both — see the spec's *pre-flight checks*
for the exact commands:

1. Does CloudFront's Origin Access Control grant cover `banana/`, or was it
   scoped to `app/*`? If scoped, every visitor gets a 403.
2. Does `/banana/` resolve to `/banana/index.html` at the edge? Depends on
   whether the origin is an S3 website endpoint or REST + OAC.

Run once with **dry_run** ticked before the first real deploy.

### Manual Rollback

Re-run the workflow from the last good tag or commit. One click, and it is the
same path automatic rollback uses.

To rehearse *automatic* rollback without an incident, dispatch once with
**force_fail_verify** ticked, after a successful deploy so there is a previous
version to restore. Nothing needs to be reset afterwards. Do **not** rehearse it
by repointing `SITE_BASE_URL` at another application — the workflow now asserts
that `SITE_BASE_URL` is an https URL ending in `/banana/` and refuses otherwise,
because a forgotten reset would silently roll back every later deploy.
````

- [ ] **Step 2: Update `CLAUDE.md`**

Replace the existing **Deployment** section at the end of `CLAUDE.md`:

```markdown
### Deployment

**Web app to S3:** deployed by the manual **Deploy web app** workflow
(`.github/workflows/deploy-webapp.yml`) to `s3://nfcarchiver.com/banana/`,
served at `https://nfcarchiver.com/banana/`. Two jobs: an uncredentialed build
(lint, test, build, bundle sanity checks) and a credentialed deploy that assumes
an AWS role via GitHub OIDC, uploads, invalidates CloudFront, verifies the live
page carries the build's `git describe` revision, and restores the previous
version if it does not. The deploy job refuses to run unless the `S3_PREFIX`
variable is exactly `banana/` — the same deploy role can also write to the
sibling app's `app/` prefix in this bucket, so changing the deploy target
requires editing the workflow, not just the variable. Design and AWS setup:
`docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md`.

Only `dist/index.html` is deployed. `yarn build` also emits `dist/js/*.js`,
which `html-webpack-inline-source-plugin` has already inlined into the HTML —
those files are dead output and must never be uploaded.

The build requires `fetch-depth: 0`: `vue.config.js` stamps the bundle with
`git describe --long --tags` and silently falls back to a short SHA without
tags, which would break the deploy's revision check. The workflow's own revision
step deliberately does **not** mirror that fallback — it fails the run instead.
`vue.config.js` keeps its fallback so a local `yarn build` works in a clone with
no tags, but the workflow must refuse what local development tolerates: a bare
7-hex SHA is a needle that can collide with unrelated hex constants in the 1.2 MB
bundle, letting the healthcheck wave a stale deploy through.

The rollback path is exercised with the `force_fail_verify` dispatch input, which
deploys for real and then forces verification to fail. Never exercise it by
repointing `SITE_BASE_URL` at another application — the deploy job now asserts
that `SITE_BASE_URL` is an https URL ending in `/${S3_PREFIX}` and refuses
otherwise.

`scripts/healthcheck.ts` (logic, unit-tested in `tests/unit/healthcheck.spec.ts`)
and `scripts/healthcheck-cli.ts` (entry point) are compiled standalone by the
workflow with explicit `tsc` flags — not under the project `tsconfig.json`,
whose `"module": "esnext"` is wrong for a Node CLI.
```

- [ ] **Step 3: Verify the doc links resolve**

```bash
test -f docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md && echo "spec link ok"
grep -q "Deploy web app" README.md && echo "readme section ok"
grep -q "deploy-webapp.yml" CLAUDE.md && echo "claude.md updated"
```

Expected: all three `ok` lines.

- [ ] **Step 4: Run the full suite one last time**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn lint --max-warnings 0 && yarn test:unit
```

Expected: clean lint, all tests passing.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document the web app deploy pipeline

Replaces the manual 'download the release asset and upload it as
index.html' instructions with the workflow, the one-time setup values,
and the two pre-flight checks that live outside the IAM role's policy."
```

---

## After the plan: operator steps

These are not code and cannot be done from this repository. Do them in order.

1. Update the IAM role's **trust policy** and **permission policy** (spec, *AWS setup*).
2. Create the `production` environment and set the six secrets/variables.
3. Run the two pre-flight checks (bucket policy OAC scope; `/banana/` index resolution).
4. Dispatch with **dry_run: true**; read the `--dryrun` plan.
5. Dispatch for real.
6. **Exercise rollback once**, after step 5 has succeeded so there is a previous version to restore: dispatch with **`force_fail_verify: true`**. The deploy runs for real and the verify step then searches for a revision that cannot exist, so check 3 fails alone while every other step succeeds — exactly the condition rollback exists for. Confirm the restore runs and the site stays on the previous version. Nothing needs resetting: the input defaults to `false` on the next dispatch. The verify step takes ~62 s, which is the healthcheck's real backoff schedule. **Do not** rehearse this by repointing `SITE_BASE_URL` at `https://nfcarchiver.com/app/` as an earlier version of this plan advised — a forgotten reset would roll every later deploy back silently, and the workflow now rejects that variable value outright.
