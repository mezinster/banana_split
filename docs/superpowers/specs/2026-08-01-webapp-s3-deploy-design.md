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
workflow_dispatch (branch selector + dry_run checkbox)
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
      3. invalidate /banana/*  → wait for status Completed
      4. healthcheck https://nfcarchiver.com/banana/
      5. on failure of 3 or 4 → restore ./previous/, invalidate, fail
```

**Why two jobs.** The build job runs `yarn install`, which executes third-party
package code. It holds no AWS token, so a compromised dependency cannot reach
S3. The deploy job never builds anything; it uploads bytes from an artifact and
runs a zero-dependency script.

**Concurrency.** `group: deploy-banana-webapp`, `cancel-in-progress: false`.
Queue, never cancel — a run cancelled mid-deploy could strand the prefix. The
group name is distinct from nfcarchiver's `deploy-webapp` so the two apps do not
block each other despite sharing a bucket.

## Component boundaries

| Unit | Purpose | Depends on |
|---|---|---|
| `.github/workflows/deploy-webapp.yml` | Orchestrate: build → upload → invalidate → verify → rollback. | the healthcheck script, AWS CLI |
| `scripts/healthcheck.ts` | Given a base URL and expected revision, assert the live deploy is correct. Exit 0/1. | Node `https` only |
| `tests/unit/healthcheck.spec.ts` | Prove the healthcheck's own logic, including its failure modes. | the script, Node `http` |
| IAM role + policies | Bound what the workflow *can* do, independently of what it *does*. | — |

The healthcheck is a standalone tested script rather than inline YAML because it
decides whether to roll back. nfcarchiver's equivalent once waved a stale deploy
through, and only a unit test caught the class of bug.

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
2. The workflow's revision step mirrors the same try/fallback logic.

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
`aws cloudfront wait invalidation-completed`. The healthcheck must not run before
propagation finishes, or it would test the old edge copy and trigger a spurious
rollback.

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

`node tools/healthcheck.js <baseUrl> <expectedRevision>`, run after invalidation
completes, against the **public domain** — exercising DNS → CloudFront → S3
rather than just the origin:

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

`tests/unit/healthcheck.spec.ts`, against a local `http.createServer` stub:

1. correct revision, correct content type → pass
2. stale revision in the body → fail, with the revision named in the failure
3. non-200 → fail
4. wrong content type → fail
5. first attempt stale, second attempt correct → pass, proving retry works

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

## `dry_run` input

A boolean `workflow_dispatch` input, default `false`. When true: build and
sanity-check as normal, run `aws s3 cp --dryrun` to print the exact object-level
plan, then stop — no upload, no invalidation, no healthcheck, no rollback. This
makes the first real deploy inspectable before it writes to a bucket shared with
another application.

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

The deploy job fails fast if any of these is empty, and asserts `S3_PREFIX` ends
with a slash — rather than letting an empty variable turn into `s3:///`.

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

### 3. Two pre-flight checks — blocking the first real deploy

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
| 2 | `scripts/healthcheck.ts` | new — post-deploy verification |
| 3 | `tests/unit/healthcheck.spec.ts` | new — 5 cases against a local server stub |
| 4 | `.gitignore` | ignore the `site/` and `tools/` staging directories |
| 5 | `README.md` | document the deploy workflow and the setup values |
| 6 | `CLAUDE.md` | note the pipeline in the web app section; correct the manual-upload deployment note |

## Testing strategy

- **Existing suite must stay green:** `yarn lint --max-warnings 0` and
  `yarn test:unit`. ESLint's `security/recommended` is active and the config sets
  `env: node`, so the script needs no `eslint-disable` for Node globals.
- **New unit tests:** the healthcheck's 5 cases above.
- **Bundle staging:** verified by the build job's own sanity checks on every run
  rather than by unit tests — checking the real output directly is stronger than
  mocking webpack.
- **First live run:** dispatch with `dry_run: true` and read the `--dryrun`
  object plan before any real deploy.
- **Rollback path:** exercised deliberately once, *after* a successful first
  deploy so there is a previous version to restore. The revision is computed
  automatically, so there is no input to falsify; instead, temporarily point the
  `SITE_BASE_URL` variable at `https://nfcarchiver.com/app/`. The healthcheck
  then fetches a page that returns 200 and `text/html` but carries no Banana
  Split revision, failing check 3 alone while every other step succeeds — which
  is exactly the condition rollback exists for. Confirm the restore runs and the
  site stays on the previous version, then set the variable back. Without this,
  rollback is untested code that only ever runs during an incident.

## Out of scope

- Any change to the crypto pipeline, shard formats, or app behaviour.
- The Flutter app, `release.yml`, `web-ci.yml`, and `flutter-ci.yml`.
- Automatic deploys on push or tag.
- Staging or preview environments.
- Creating or reconfiguring the S3 bucket, CloudFront distribution, ACM
  certificate, DNS, or the OIDC identity provider — all already exist.
