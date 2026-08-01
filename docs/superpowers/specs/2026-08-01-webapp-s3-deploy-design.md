# Manually-triggered S3 + CloudFront delivery pipeline for the web app

**Date:** 2026-08-01
**Scope:** Delivery of the Vue web app only — a GitHub Actions workflow, a
post-deploy healthcheck script, and its unit tests. No change to the crypto
pipeline, app behaviour, the Flutter app, or the release workflow.

## Problem

The web app has no deployment path. `.github/workflows/release.yml` builds
`banana-split-web-X.Y.Z.html` and attaches it to a GitHub Release; getting that
file onto a web server is a manual download-and-upload, documented in
`CLAUDE.md` as "upload as `index.html` to an S3 bucket". Three defects follow:

1. **Nothing verifies a deploy.** No check that the bytes served by CloudFront
   are the bytes that were built, and no cache invalidation, so a deploy can
   silently leave a stale page at the edge.
2. **No rollback.** Recovering from a bad upload means finding the previous
   release asset by hand and repeating the manual upload.
3. **The upload target is a shared bucket.** `nfcarchiver.com` already hosts the
   NFC Archiver web app at the `app/` prefix. A hand-run `aws s3 sync --delete`
   against the wrong prefix would delete another application.

The sibling project `mezinster/nfcarchiver` solved this for its own web app in
`.github/workflows/deploy-webapp.yml`. This design ports that pipeline, adapted
to a build that emits a single self-contained file.

## Decisions (confirmed with user)

1. **Trigger:** `workflow_dispatch` only. Never on push or tag.
2. **Credentials:** GitHub OIDC federation. No long-lived AWS keys anywhere.
3. **Target:** `s3://nfcarchiver.com/banana/`, served at
   `https://nfcarchiver.com/banana/` by the existing CloudFront distribution
   `EPIRQ7CFJKRDQ`. Same bucket and same distribution as NFC Archiver.
4. **IAM:** reuse the existing `nfcarchiver` deploy role with an expanded trust
   policy and permission policy, rather than creating a second role.
5. **Approval:** none. The manual trigger is the only gate; the `production`
   GitHub Environment carries zero required reviewers and exists to pin the OIDC
   trust policy and restrict deploys to `master`.
6. **Verification:** pre-flight (lint, tests, build, bundle sanity) plus
   post-deploy verification through the public domain, including a revision
   match.
7. **On verification failure:** automatic rollback to the previous live file,
   then fail the run.

## Architecture

Two jobs. The credential-bearing job does the minimum possible work.

```
workflow_dispatch (branch selector + dry_run / force_fail_verify checkboxes)
│
├── job: build ──────────────── permissions: {}   (no AWS access at all)
│     checkout with fetch-depth: 0        (tags are required — see below)
│     node 14 (.nvmrc) · yarn install · yarn lint · yarn test:unit · yarn build
│     revision = git describe --long --tags
│     bundle sanity checks
│     stage ONLY dist/index.html → site/
│     compile scripts/healthcheck.ts → tools/
│     └─ upload-artifact: "site" and "deploy-tools"
│
└── job: deploy ─────────────── environment: production
      needs: build              permissions: { id-token: write, contents: read }
      download-artifact · aws-actions/configure-aws-credentials (assume role)
      1. snapshot   s3://$BUCKET/banana/index.html → ./previous/
      2. upload     site/index.html → s3://$BUCKET/banana/index.html
      3. invalidate /banana/*  → wait (non-fatal: warn and continue on timeout)
      4. healthcheck https://nfcarchiver.com/banana/
      5. on failure of 3 or 4 → restore ./previous/, invalidate, fail
```

**Why two jobs.** The build job runs `yarn install`, which executes third-party
package code. It holds no AWS token, so a compromised dependency cannot reach
S3. The deploy job never builds anything; it uploads bytes from an artifact and
runs a zero-dependency script.

**Concurrency.** `group: deploy-banana-webapp`, `cancel-in-progress: false`.
Queue, never cancel — a run cancelled mid-deploy could strand the prefix. This
serialises *this repository's* own deploys, so two dispatches cannot interleave
one run's snapshot with another's upload. It says nothing about the sibling app:
concurrency groups are scoped to a repository, so nfcarchiver's runs were never
in this group's scope whatever it is named. The two apps sharing a bucket are not
serialised against each other by anything, and do not need to be — they write
disjoint prefixes.

## Component boundaries

| Unit | Purpose | Depends on |
|---|---|---|
| `.github/workflows/deploy-webapp.yml` | Orchestrate: build → upload → invalidate → verify → rollback. | the healthcheck script, AWS CLI |
| `scripts/healthcheck.ts` | Given a base URL and expected revision, assert the live deploy is correct. | Node `https` only |
| `scripts/healthcheck-cli.ts` | CLI entry point. Exit **0** healthy, **1** unhealthy, **2** bad usage. | the module above |
| `tests/unit/healthcheck.spec.ts` | Prove the healthcheck's own logic, including its failure modes. | the script, Node `http` |
| IAM role + policies | Bound what the workflow *can* do, independently of what it *does*. | — |

The healthcheck is a standalone tested script rather than inline YAML because it
decides whether to roll back. nfcarchiver's equivalent once waved a stale deploy
through, and only a unit test caught the class of bug.

Exit **2** is not a formality. The build job's `Verify the compiled healthcheck
starts` step invokes the CLI with no arguments and asserts it exits exactly 2 —
that is how the workflow proves the compiled artifact loads under Node *before*
the credentialed job depends on it. A 2 that became a 1 would mean the deploy
job could not tell "we invoked this wrong" from "roll back".

## What is simpler here than in nfcarchiver

Deliberate removals, not oversights. nfcarchiver ships `index.html` plus
`dist/main.js`; this app inlines everything into one file via
`html-webpack-inline-source-plugin` (`vue.config.js:23`).

| nfcarchiver | Banana Split | Why |
|---|---|---|
| Two sync passes, different `Cache-Control` per file type | One `aws s3 cp` | One object. No asset tree. |
| `index.html` uploaded **last** | No ordering constraint | Nothing references anything else. |
| `--delete` scoped to the prefix | **No `--delete` at all** | One object with a fixed key. `--delete` has no work to do and only carries blast-radius risk. |
| Synthetic `nfar-build:<sha>` banner via a shared `build-marker.ts` | Existing `GIT_REVISION` | See below. |

### The build marker already exists

`vue.config.js:9` injects `git describe --long --tags` as `GIT_REVISION` via
`DefinePlugin`; `App.vue:41` and `ShardQrCode.vue:56` render it. Verified against
a real build of `dist/index.html`: the literal string `v0.8.3-4-gca75a75` occurs
**exactly once** in 1.2 MB.

nfcarchiver needed a synthetic sentinel because its bare 7-hex-character SHA
needle collided with unrelated hex constants in its bundle. `git describe` output
has a `vN.N.N-N-g<sha>` shape that cannot occur by coincidence, so the raw
revision string is a safe needle here. **No build-config change is required.**

### The workflow must not compute the revision independently

`vue.config.js:7-12` tries `git describe --long --tags` and **falls back** to
`git rev-parse --short HEAD` when it throws. The workflow needs the same string
the build baked in, so two things are required:

1. `actions/checkout` with `fetch-depth: 0`. The default shallow clone fetches no
   tags, `git describe` throws, and the build silently falls back to a short SHA.
2. The workflow's revision step runs the same `git describe --long --tags`.

**But the workflow deliberately does NOT mirror the fallback.** `vue.config.js`
keeps `git rev-parse --short HEAD` so a local `yarn build` works in a clone with
no tags; the workflow's revision step instead **fails the run** if
`git describe` cannot produce a tag-based string. The reason is the needle. A
bare 7-hex-character SHA is exactly the shape that collides with unrelated hex
constants inside a 1.2 MB bundle — the precise problem that forced nfcarchiver
to invent a synthetic `nfar-build:<sha>` marker (see *The build marker already
exists* above). If the fallback ever fired here, `checkOnce`'s `indexOf` could
match an unrelated hex run and wave a stale deploy through. The workflow must
refuse what local development may tolerate, so the divergence is intentional
and must not be "fixed" by re-adding the fallback.

Sanity check 2 below is what makes this safe rather than merely likely: it greps
the built `dist/index.html` for the revision the workflow computed. If the two
ever diverge, the run fails in the uncredentialed build job — not as a spurious
rollback after a perfectly good deploy.

## Build: staging and sanity checks

### Stage only `dist/index.html`

`yarn build` emits both the self-contained `dist/index.html` (1.2 MB) **and**
`dist/js/app.*.js` + `dist/js/chunk-vendors.*.js` (1.2 MB combined). The inline
plugin inlines the chunks into the HTML but webpack still writes the originals.
Verified: `dist/index.html` contains no `src=` or `href=` reference to any local
file.

`dist/js/` is therefore dead output. The workflow copies **only
`dist/index.html`** into `site/`. A naive `aws s3 sync ./dist/` would upload
1.2 MB of dead weight and publish the raw bundles at `/banana/js/*.js`.

### Sanity checks, in the build job, before any credential is in scope

1. `dist/index.html` exists and is non-empty.
2. It contains the `git describe` revision string — proves `DefinePlugin` ran.
3. It contains no `src=`/`href=` reference to a local file.

Check 3 is load-bearing. If the inline plugin ever silently stops inlining — a
webpack or plugin bump — the build still "succeeds" and emits an `index.html`
referencing `js/app.*.js`, files this workflow deliberately does not upload. The
result would be a blank page in production. Catching it costs one `grep`.

### Two further build-job steps

Both exist for reasons that are not obvious from their names, so neither should
be removed as redundant.

**`Lint deploy scripts`.** `yarn lint` runs `vue-cli-service lint`, whose default
glob is `src`, `tests`, and top-level `*.js` — it does **not** include `scripts/`.
Without this extra invocation (`yarn lint --no-fix --max-warnings 0
scripts/healthcheck.ts scripts/healthcheck-cli.ts`) the code that gates a
production rollback would be the only unlinted code in the repository.

**`Verify the compiled healthcheck starts`.** Runs `node tools/healthcheck-cli.js`
with no arguments and asserts it exits exactly `2`. The deploy job downloads this
compiled artifact and runs it while holding AWS credentials, never having
type-checked or executed it; a `tsc` output that throws on `require` would
otherwise surface as a mid-deploy failure and a spurious rollback. Proving the
binary loads costs one invocation in the uncredentialed job.

This step is also where the pipeline's one shipped blocking bug lived, and the
shape of it is worth recording. GitHub Actions invokes every `run:` body as
`bash -e {0}`. The step opened with `set -uo pipefail`, which *adds* `-u` and
`pipefail` but cannot remove the inherited `-e`. Because the `node` call exits 2
**by design**, errexit aborted the script on that very line: `code=$?` was never
reached and the step failed with exit 2 on every run, so no dispatch could ever
complete. The fix is `node ... || code=$?` with `code` pre-initialised. The same
trap applies to any `run:` body that expects a non-zero exit — a bare `set -uo
pipefail` is not an escape from errexit.

## Upload and cache headers

Single object:

| Object | `Cache-Control` | `Content-Type` |
|---|---|---|
| `banana/index.html` | `no-cache` | `text/html; charset=utf-8` |

`no-cache` is **not** `no-store`. The browser stores the file and revalidates
with `If-None-Match`; an unchanged build returns a bodyless 304, so repeat
visitors pay one round trip rather than 1.2 MB. `no-store` would forbid storage
and force a full re-download every visit.

There is no content-hashed-asset alternative to reach for: the HTML *is* the
bundle, so its cache policy and the app's cache policy are one decision.
Correctness comes from the invalidation; `no-cache` is what lets a user who
reloads get the new build even before the edge finishes propagating.

Content type is set **explicitly** rather than relying on S3's guessing.

## Scoping: the shared-bucket constraint

`nfcarchiver.com` hosts multiple applications. Every S3 operation is
prefix-bound, and the IAM policy makes an out-of-scope operation *fail* rather
than merely being absent from the workflow:

| Operation | Scope | IAM-enforced? |
|---|---|---|
| object read/write/delete | `s3://nfcarchiver.com/banana/` | yes — `Resource` |
| `ListBucket` | prefix `banana/` | yes — `s3:prefix` condition |
| Invalidation paths | `/banana/*`, never `/*` | **no** — see below |

**CloudFront invalidation paths cannot be restricted by IAM.**
`cloudfront:CreateInvalidation` accepts only the distribution ARN as a resource;
there is no condition key for the `Paths` parameter. So for S3 the prefix
scoping is defence in depth, but for CloudFront it is workflow-level only —
correct paths in the YAML, with nothing behind them. This is a property of the
CloudFront API, not an omission. The blast radius of getting it wrong is a cache
flush of a sibling app, not data loss, which is why it is accepted. The existing
policy's `Sid` `InvalidateAppPaths` is renamed to `InvalidateDistribution` so it
stops implying a boundary that does not exist.

## Invalidation

`aws cloudfront create-invalidation --paths '/banana/*'`, then
`aws cloudfront wait invalidation-completed`. The healthcheck should not run
before propagation finishes, or it would test the old edge copy and trigger a
spurious rollback.

**The wait is non-fatal.** `aws cloudfront wait` polls 20 s × 30 and exits
non-zero at ~10 minutes. Under `set -e` a slow-but-successful invalidation would
fail the step, fire `failure()`, and let rollback overwrite a perfectly good
deploy. So the wait is wrapped in an `if`: on timeout the step logs a `::warning::`
and continues. The object is served `Cache-Control: no-cache`, so edges
revalidate against S3 on every request regardless — the invalidation is
belt-and-braces, and the healthcheck's own 6-attempt/~62 s retry is the real
arbiter of whether the edge is serving this build. A failure of
`create-invalidation` itself is still fatal; only the wait is tolerated.

The rollback step's invalidation wait gets the same treatment: the restore has
already succeeded by that point, so a slow invalidation must not report a
successful rollback as failed.

## Healthcheck

`scripts/healthcheck.ts`, written in TypeScript so the existing ts-jest setup
tests it with **no Jest or tsconfig change** (`tsconfig.json` has `allowJs`
disabled, so a plain `.js` script could not be transformed). The build job
compiles it to CommonJS with the already-present `typescript@4.4.3` and ships it
as the `deploy-tools` artifact. The deploy job runs plain, zero-dependency JS —
it never checks out the repo or runs `yarn install`.

Compiled standalone with explicit flags (`--module commonjs --target es2019`)
rather than under the project `tsconfig.json`, whose `"module": "esnext"` is
wrong for a Node CLI.

Split into two files. `scripts/healthcheck.ts` holds the logic and is
**side-effect free** — importing it performs no I/O and never reads
`process.argv`, so the test file gets the functions with nothing else running.
`scripts/healthcheck-cli.ts` is a trivial entry point that parses arguments and
sets the exit code. This avoids a `require.main === module` guard, whose
behaviour depends on the module system the file happens to be compiled under —
and this project compiles the same source two ways (ts-jest for tests, explicit
`tsc` flags for the workflow).

`node tools/healthcheck-cli.js <baseUrl> <expectedRevision>`, run after
invalidation completes, against the **public domain** — exercising DNS →
CloudFront → S3 rather than just the origin:

1. `GET https://nfcarchiver.com/banana/` → 200
2. `content-type` starts with `text/html`
3. the body **contains the expected revision string**

Requests send `Cache-Control: no-cache`. Each pass retries with exponential
backoff for ~62 s across 6 attempts to absorb residual edge propagation, then
fails. One pass collects every failure rather than stopping at the first, so a
failing deploy reports everything wrong with it in one log.

Uses Node's `https` module rather than global `fetch`: this repo's Jest runs on
Node 14, which has no `fetch`. With `https`, the unit tests exercise **the same
code path that runs in production** against a real local `http.createServer`
stub, rather than asserting against an injected fetch stub.

Check 3 is the load-bearing one. Checks 1 and 2 catch a broken upload or a
misconfigured content type; only check 3 distinguishes "the deploy worked" from
"an older version is still being served".

Per repo convention (`CLAUDE.md`), the script avoids optional chaining and
nullish coalescing.

### Unit tests

`tests/unit/healthcheck.spec.ts`, 10 cases against a local `http.createServer`
stub:

1. correct revision, correct content type → pass
2. stale revision in the body → fail, with the revision named in the failure
3. non-200 → fail
4. wrong content type → fail
5. one pass collects *every* failure (500 **and** wrong content type) rather than
   stopping at the first
6. an empty expected revision is refused before any request is issued — `""`
   would otherwise match every possible body via `indexOf`
7. first attempt stale, second attempt correct → pass, proving retry works
8. **every attempt stale → fail**, with the revision named and exactly `attempts`
   requests issued
9. a base URL with no trailing slash is normalised
10. a refused connection is reported as a failure, not thrown

Case 8 is the one that constrains the rollback trigger. Without it, replacing
`healthcheck()`'s final `return last;` with `return { ok: true, failures: [] };`
leaves cases 1–7 green while reporting every deploy healthy and disabling
rollback permanently — verified by applying exactly that mutation and confirming
case 8, and only case 8, fails.

A healthcheck that mis-fires either triggers a needless rollback or waves a stale
deploy through, so its own logic is worth testing.

## Rollback

Step 1 copies the live file into `./previous/` before anything is overwritten,
using `aws s3 sync` rather than `cp` so a **first deploy against an empty prefix
succeeds** instead of erroring on a missing key.

If invalidation or the healthcheck fails, the workflow restores
`./previous/index.html` with the same explicit headers, issues a second
invalidation, waits for it, and then fails the run loudly. One 1.2 MB file —
effectively instant.

The restore step is guarded on the snapshot having succeeded **and** having
actually captured a file. On a first deploy there is nothing to restore, and the
workflow says so plainly rather than pretending it rolled back.

**No S3 bucket versioning.** That is a bucket-wide setting on a bucket shared
with other applications; changing its storage and lifecycle semantics for this
one prefix is disproportionate.

**Stated limitation.** If the runner dies between upload and healthcheck, nothing
auto-restores. Recovery is to re-dispatch the workflow from the last good tag or
commit — which is also the intended manual rollback path, and is one click. This
is accepted rather than engineered around.

## Dispatch inputs

### `dry_run`

A boolean `workflow_dispatch` input, default `false`. When true: build and
sanity-check as normal, run `aws s3 cp --dryrun` to print the exact object-level
plan, then stop — no upload, no invalidation, no healthcheck, no rollback. This
makes the first real deploy inspectable before it writes to a bucket shared with
another application.

### `force_fail_verify`

A boolean `workflow_dispatch` input, default `false`. When true the deploy runs
for real — snapshot, upload, invalidate — and then the verify step calls the
healthcheck with the literal revision `force-fail-verify-no-such-revision`, which
cannot match any page. Verification fails, `failure()` fires, and the rollback
path executes exactly as it would in a real incident.

This exists so the rollback drill can be performed without touching
configuration. The earlier documented drill — temporarily repoint `SITE_BASE_URL`
at `https://nfcarchiver.com/app/`, dispatch, then set it back — was dangerous:
if the operator forgot the last step, every subsequent deploy would upload to
`banana/`, healthcheck the *other application's* page, fail, and roll `banana/`
back, silently and indefinitely. Assertion 4 of the configuration check now makes
that variable state fail closed, so the old drill is no longer performable at all.

The forced run takes ~62 s at the verify step, because that is the healthcheck's
real backoff schedule. That is correct: the drill exercises the actual timing the
rollback path has in production.

### Run summary

The `Summary` step is guarded on `always()` alone — including dry runs, since a
dry run is precisely the run whose purpose is to show what would happen. On a dry
run the invalidate/verify/rollback cells read `n/a` or `skipped`, which is the
informative answer. The table reports mode, build revision, ref, target key, URL,
invalidation id, verify outcome and **rollback outcome** — after a red run, that
last one is the single fact an operator most needs. Every value reaches the shell
through `env:`; nothing is interpolated into a `run:` body on a runner holding
credentials for two production prefixes.

## Configuration

Set once during setup, in the `mezinster/banana_split` repository. No value below
is an AWS credential.

| Kind | Name | Value |
|---|---|---|
| Secret | `AWS_DEPLOY_ROLE_ARN` | the existing nfcarchiver deploy role ARN — held as a secret so the account ID is masked in logs |
| Variable | `AWS_REGION` | bucket region |
| Variable | `S3_BUCKET` | `nfcarchiver.com` |
| Variable | `S3_PREFIX` | `banana/` |
| Variable | `CLOUDFRONT_DISTRIBUTION_ID` | `EPIRQ7CFJKRDQ` |
| Variable | `SITE_BASE_URL` | `https://nfcarchiver.com/banana/` |

### The configuration check is a security control, not a typo guard

The deploy job's `Check configuration is present` step makes four assertions.
The first two are hygiene; the last two are the only things standing between
this workflow and the sibling production application in the same bucket, and
must not be removed.

1. **None of `S3_BUCKET`, `S3_PREFIX`, `CLOUDFRONT_DISTRIBUTION_ID`,
   `SITE_BASE_URL` or the computed revision is empty** — rather than letting an
   unset variable turn into `s3:///` or a masked-out path deep inside an upload
   command.
2. **`S3_PREFIX` ends with a slash.** Shape only. Without it,
   `s3://bucket/bananaindex.html` is a perfectly valid key.
3. **`S3_PREFIX` is exactly `banana/`** — a pin on the *value*, not the shape.
   This is the important one. The deploy role can also write to `app/`, and
   CloudFront invalidation paths cannot be IAM-restricted at all (see *Scoping*
   above), so on the write path this variable's value is the **only** boundary
   protecting the other application. A mistyped or maliciously-edited `app/`
   passes checks 1 and 2 and would overwrite a different production app. It is
   deliberately not derived from anything: changing the deploy target requires
   editing the workflow, which is a reviewed change, rather than flipping a
   repository variable, which is not. **Do not delete this as redundant with the
   slash check** — they test different things, and only this one has teeth.
4. **`SITE_BASE_URL` is an `https://` URL ending in `/${PREFIX}`.** The healthcheck
   must verify the page this run actually deployed. If `SITE_BASE_URL` points
   anywhere else — most plausibly the sibling app at `https://nfcarchiver.com/app/`,
   which happily returns 200 and `text/html` — then every deploy would upload to
   `banana/`, healthcheck a page that can never carry this build's revision, fail,
   and roll `banana/` back to the previous version. Silently, run after run, with
   an error message pointing at CloudFront rather than at the variable. This
   assertion makes that configuration fail closed, before any credential is used.

Implemented as `case "${BASE_URL}" in https://*/"${PREFIX}") ;; *) …` — the
quoted `${PREFIX}` expansion inside the pattern is matched literally, so
`https://nfcarchiver.com/banana/` passes while `https://nfcarchiver.com/app/`,
`http://nfcarchiver.com/banana/`, `nfcarchiver.com/banana/`, and
`https://nfcarchiver.com/banana` (no trailing slash) are all rejected.

Plus **GitHub → Settings → Environments → New environment `production`**:
required reviewers **none**, deployment branches **selected branches → `master`**.

## AWS setup (operator steps)

The OIDC identity provider and the role already exist from the nfcarchiver
setup. Both of the role's policies are replaced.

### 1. Trust policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::533267300952:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": [
            "repo:mezinster/nfcarchiver:environment:production",
            "repo:mezinster/banana_split:environment:production"
          ]
        }
      }
    }
  ]
}
```

The `sub` condition is the entire security boundary. `StringEquals` with an array
means "equals any one of these" — still exact matching. It must never become
`StringLike` with a wildcard, which would let any repository assume this role.

### 2. Permission policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DeployPrefixObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::nfcarchiver.com/app/*",
        "arn:aws:s3:::nfcarchiver.com/banana/*"
      ]
    },
    {
      "Sid": "ListDeployPrefixesOnly",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::nfcarchiver.com",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["app", "app/*", "banana", "banana/*"]
        }
      }
    },
    {
      "Sid": "InvalidateDistribution",
      "Effect": "Allow",
      "Action": ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"],
      "Resource": "arn:aws:cloudfront::533267300952:distribution/EPIRQ7CFJKRDQ"
    }
  ]
}
```

`s3:prefix` needs both the bare and the slashed form of each prefix:
`aws s3 sync s3://nfcarchiver.com/banana/` sends `ListObjectsV2` with
`prefix=banana/`, which matches `banana/*` because IAM's `*` matches zero or more
characters; the bare `banana` entry covers a listing with no trailing slash.

The `Resource` list and the `s3:prefix` list must be kept in sync. They are
separate mechanisms and fail differently: with `Resource` only, a sync dies on
its first `ListObjectsV2`; with the prefix condition only, the sync lists an
empty prefix, decides every file needs uploading, then 403s on `PutObject`.

**Single role across two repositories — accepted tradeoff.** A compromise of
either repository's `production` environment can write to both prefixes. A second
role would isolate them. Recorded, not relitigated.

### 3. Two pre-flight checks — RESOLVED 2026-08-01

**Status: both confirmed by the operator; neither blocks the first deploy.**
`/banana/` resolves to `/banana/index.html`, exactly as `/app/` does, so check
(b) passes. The IAM trust and permission policy changes below have been applied.
The `production` environment restricts deployments to `master`. The distribution
has **no custom error pages**, which matters for the healthcheck: a missing key
returns a genuine 403/404 rather than a 200 carrying an error document, so the
healthcheck's status and content-type checks mean what they say.

The reasoning is retained below for the next person who adds a prefix to this
bucket — the checks are not obsolete, they are answered for `banana/`.

Both concern layers *outside* this role's policy, and both produce the same
symptom — "the deploy succeeded and the page is broken" — so they must be checked
separately rather than conflated while debugging.

**(a) Does CloudFront's OAC grant cover `banana/`?** The bucket policy is separate
from the role policy. With Origin Access Control the bucket grants
`cloudfront.amazonaws.com` `s3:GetObject`. If that grant reads
`arn:aws:s3:::nfcarchiver.com/*`, this is fine. If it was scoped to
`arn:aws:s3:::nfcarchiver.com/app/*`, then `/banana/index.html` uploads
perfectly, invalidates perfectly, and returns **403 to every visitor** because
CloudFront itself cannot read it.

```bash
aws s3api get-bucket-policy --bucket nfcarchiver.com --query Policy --output text | jq .
```

**(b) Does `/banana/` resolve to `/banana/index.html`?** This depends on origin
type. An **S3 website endpoint** origin applies the index document to every
"directory", so a new sibling prefix works automatically. A **REST endpoint +
OAC** origin does not — `DefaultRootObject` applies only at `/`, and subfolder
index resolution requires a CloudFront Function, which may be written to match
`/app/` specifically.

```bash
aws cloudfront get-distribution-config --id EPIRQ7CFJKRDQ \
  --query 'DistributionConfig.{Origins:Origins.Items[].DomainName,Default:DefaultCacheBehavior.FunctionAssociations}'
```

If (b) fails, the fix is a CloudFront Function append-index rule, or linking to
`/banana/index.html` explicitly. Uploading the file to both `banana/index.html`
and `banana` (no slash) is **not** the fix — it creates two objects that drift.

**(c) Object ACLs.** nfcarchiver deploys successfully today without
`s3:PutObjectAcl`, which establishes that the bucket has ACLs disabled (OAC plus
bucket policy). No `--acl public-read` and no extra grant is needed. Noted so the
question is not reopened.

## Repository changes

| # | File | Change |
|---|---|---|
| 1 | `.github/workflows/deploy-webapp.yml` | new — the pipeline |
| 2 | `scripts/healthcheck.ts` | new — post-deploy verification logic, side-effect free |
| 3 | `scripts/healthcheck-cli.ts` | new — command-line entry point |
| 4 | `tests/unit/healthcheck.spec.ts` | new — 10 cases against a local server stub |
| 5 | `.gitignore` | ignore the `site/` and `tools/` staging directories |
| 6 | `README.md` | document the deploy workflow and the setup values |
| 7 | `CLAUDE.md` | note the pipeline in the web app section; correct the manual-upload deployment note |

## Testing strategy

- **Existing suite must stay green:** `yarn lint --max-warnings 0` and
  `yarn test:unit`. ESLint's `security/recommended` is active and the config sets
  `env: node`, so the script needs no `eslint-disable` for Node globals.
- **New unit tests:** the healthcheck's 10 cases above.
- **Bundle staging:** verified by the build job's own sanity checks on every run
  rather than by unit tests — checking the real output directly is stronger than
  mocking webpack.
- **First live run:** dispatch with `dry_run: true` and read the `--dryrun`
  object plan before any real deploy.
- **Rollback path:** exercised deliberately once, *after* a successful first
  deploy so there is a previous version to restore. Dispatch with
  **`force_fail_verify: true`**. The deploy runs for real and the verify step then
  searches for a revision that cannot exist, failing check 3 alone while every
  other step succeeds — exactly the condition rollback exists for. Confirm the
  restore runs and the site stays on the previous version. Nothing needs to be
  set back afterwards: the input defaults to `false` on the next dispatch.
  Without this, rollback is untested code that only ever runs during an incident.

  This replaces an earlier drill that temporarily repointed `SITE_BASE_URL` at
  `https://nfcarchiver.com/app/`. That drill left a trap — a forgotten reset
  would roll every subsequent deploy back, silently — and the configuration
  check's `SITE_BASE_URL` assertion now rejects it outright.

## Out of scope

- Any change to the crypto pipeline, shard formats, or app behaviour.
- The Flutter app, `release.yml`, `web-ci.yml`, and `flutter-ci.yml`.
- Automatic deploys on push or tag.
- Staging or preview environments.
- Creating or reconfiguring the S3 bucket, CloudFront distribution, ACM
  certificate, DNS, or the OIDC identity provider — all already exist.
