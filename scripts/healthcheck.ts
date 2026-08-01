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

/** Node's http/https modules send NO User-Agent by default — unlike fetch,
 *  curl, or any browser. A request without one is blocked outright by common
 *  WAF rulesets (AWSManagedRulesCommonRuleSet's NoUserAgent_HEADER returns
 *  403), which made this healthcheck structurally incapable of ever returning
 *  200 against the deploy target: it reported UNHEALTHY and rolled back two
 *  perfectly good deploys before the cause was found. Identify ourselves. */
export const USER_AGENT = "banana-split-deploy-healthcheck/1 (+https://github.com/mezinster/banana_split)";

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
        headers: {
          "cache-control": "no-cache",
          pragma: "no-cache",
          "user-agent": USER_AGENT
        }
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
