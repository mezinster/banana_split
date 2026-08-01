# Web App S3 + CloudFront Deploy Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually-triggered GitHub Actions workflow that builds the Vue web app, uploads the single self-contained `index.html` to `s3://nfcarchiver.com/banana/`, invalidates CloudFront, verifies the live site serves that exact build, and rolls back automatically if it does not.

**Architecture:** Two jobs. An uncredentialed `build` job runs `yarn install` (third-party code) and produces two artifacts: the deployable file and a compiled healthcheck script. A credentialed `deploy` job assumes an AWS role via OIDC, uploads bytes from the artifact, invalidates, verifies, and restores a pre-upload snapshot on failure. It never builds anything and never runs `yarn install`.

**Tech Stack:** GitHub Actions, AWS CLI v2 (preinstalled on `ubuntu-latest`), OIDC federation via `aws-actions/configure-aws-credentials`, TypeScript 4.4.3 (already a dependency), Jest + ts-jest 26 (already configured), Node 14 for the build (`.nvmrc`), Node 20 for the deploy job.

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

export type Fetcher = (url: string) => Promise<FetchedPage>;

export interface CheckResult {
  ok: boolean;
  failures: string[];
}

export interface HealthcheckOptions {
  attempts?: number;
  firstDelayMs?: number;
  fetcher?: Fetcher;
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
      console.error("attempt " + attempt + "/" + attempts + " failed:");
      last.failures.forEach(failure => console.error("  - " + failure));
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

Expected: PASS — 5 passed.

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

if (baseUrl === undefined || expectedRevision === undefined) {
  console.error("usage: node healthcheck-cli.js <baseUrl> <expectedRevision>");
  process.exit(2);
}

healthcheck(baseUrl, expectedRevision).then(
  result => {
    if (result.ok) {
      console.log("healthy: " + baseUrl + " is serving build " + expectedRevision);
      process.exit(0);
    }
    console.error("UNHEALTHY:");
    result.failures.forEach(failure => console.error("  - " + failure));
    process.exit(1);
  },
  error => {
    console.error("healthcheck crashed: " + String(error));
    process.exit(1);
  }
);
```

- [ ] **Step 2: Ignore the staging directories**

Add to `.gitignore`, after the existing `/dist` line:

```gitignore
# deploy pipeline staging directories
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

# No ambient permissions anywhere. The deploy job opts in to id-token below.
permissions: {}

concurrency:
  # Queue, never cancel: a run cancelled mid-deploy could strand the prefix.
  # The group name is distinct from nfcarchiver's so the two apps sharing this
  # bucket do not block each other.
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

      - name: Unit tests
        run: yarn test:unit

      - name: Compute build revision
        id: stamp
        # Mirrors vue.config.js:7-12 exactly, fallback included, so the string
        # we search for is the string the build baked in.
        run: |
          set -euo pipefail
          revision="$(git describe --long --tags 2>/dev/null || git rev-parse --short HEAD)"
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
        # does not upload — and production would serve a blank page.
        run: |
          set -euo pipefail
          f=dist/index.html
          [ -s "$f" ] || { echo "::error::$f is missing or empty"; exit 1; }

          grep -qF "$REVISION" "$f" || {
            echo "::error::$f does not contain revision ${REVISION} — either DefinePlugin did not run, or this workflow and vue.config.js disagree about the revision"
            exit 1
          }

          if grep -qE '(src|href)="(\./)?(js|css)/' "$f"; then
            echo "::error::$f references external assets — the inline-source plugin did not inline them"
            grep -oE '(src|href)="(\./)?(js|css)/[^"]*"' "$f" | sort -u
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
        run: |
          set -uo pipefail
          node tools/healthcheck-cli.js >/dev/null 2>&1
          code=$?
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
REVISION="$(git describe --long --tags 2>/dev/null || git rev-parse --short HEAD)" && \
f=dist/index.html && \
[ -s "$f" ] && echo "non-empty ok" && \
grep -qF "$REVISION" "$f" && echo "revision ${REVISION} present" && \
! grep -qE '(src|href)="(\./)?(js|css)/' "$f" && echo "fully inlined ok"
```

Expected: `non-empty ok`, `revision <something> present`, `fully inlined ok`.

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
          # The healthcheck must not run before propagation finishes, or it
          # would test the old edge copy and trigger a spurious rollback.
          aws cloudfront wait invalidation-completed \
            --distribution-id "${DIST_ID}" --id "${id}"
          echo "invalidation ${id} completed"

      - name: Verify the live site serves this build
        id: verify
        if: ${{ !inputs.dry_run }}
        run: node tools/healthcheck-cli.js "${BASE_URL}" "${REVISION}"

      - name: Roll back to the previous version
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
          aws cloudfront wait invalidation-completed \
            --distribution-id "${DIST_ID}" --id "${rollback_id}"
          echo "rolled back; invalidation ${rollback_id} completed"

      - name: Report that rollback was not possible
        if: ${{ failure() && !inputs.dry_run && steps.snapshot.outputs.captured != 'true' && steps.upload.outcome != 'skipped' }}
        run: |
          echo "::error::Deploy failed and there was no previous version to restore (first deploy). The prefix now holds build ${REVISION}, unverified."

      - name: Summary
        if: ${{ always() && !inputs.dry_run }}
        run: |
          {
            echo "### Banana Split web app deploy"
            echo ""
            echo "| field | value |"
            echo "|---|---|"
            echo "| build | \`${REVISION}\` |"
            echo "| ref | \`${{ github.ref_name }}\` |"
            echo "| target | \`s3://${BUCKET}/${PREFIX}index.html\` |"
            echo "| url | ${BASE_URL} |"
            echo "| invalidation | \`${{ steps.invalidate.outputs.invalidation || 'n/a' }}\` |"
            echo "| verify | ${{ steps.verify.outcome || 'did not run' }} |"
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
## Deploying the web app

The web app is deployed to `https://nfcarchiver.com/banana/` by the
**Deploy web app** workflow (`.github/workflows/deploy-webapp.yml`). It is
**manual only** — it never runs on push or tag.

Actions → Deploy web app → Run workflow. Pick a ref, optionally tick
**dry_run** to print the upload plan without uploading anything.

The workflow builds and verifies the bundle in a job with no AWS access, then
uploads, invalidates CloudFront, and checks that the live URL serves the exact
build it produced. If that check fails it restores the previous version
automatically and fails the run.

### One-time setup

**Repository → Settings → Secrets and variables → Actions**

| Kind | Name | Value |
|---|---|---|
| Secret | `AWS_DEPLOY_ROLE_ARN` | the deploy role ARN (secret, so the account ID is masked in logs) |
| Variable | `AWS_REGION` | the bucket's region |
| Variable | `S3_BUCKET` | `nfcarchiver.com` |
| Variable | `S3_PREFIX` | `banana/` (must end with a slash) |
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

### Before the first real deploy

Two things live outside the role's policy and will produce a successful-looking
deploy that serves a broken page. Check both — see the spec's *pre-flight checks*
for the exact commands:

1. Does CloudFront's Origin Access Control grant cover `banana/`, or was it
   scoped to `app/*`? If scoped, every visitor gets a 403.
2. Does `/banana/` resolve to `/banana/index.html` at the edge? Depends on
   whether the origin is an S3 website endpoint or REST + OAC.

Run once with **dry_run** ticked before the first real deploy.

### Manual rollback

Re-run the workflow from the last good tag or commit. One click, and it is the
same path automatic rollback uses.
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
version if it does not. Design and AWS setup:
`docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md`.

Only `dist/index.html` is deployed. `yarn build` also emits `dist/js/*.js`,
which `html-webpack-inline-source-plugin` has already inlined into the HTML —
those files are dead output and must never be uploaded.

The build requires `fetch-depth: 0`: `vue.config.js` stamps the bundle with
`git describe --long --tags` and silently falls back to a short SHA without
tags, which would break the deploy's revision check.

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
6. **Exercise rollback once**, after step 5 has succeeded so there is a previous version to restore: temporarily set `SITE_BASE_URL` to `https://nfcarchiver.com/app/` and dispatch. That URL returns 200 and `text/html` but carries no Banana Split revision, so check 3 fails alone while every other step succeeds — exactly the condition rollback exists for. Confirm the restore runs, then set the variable back.
