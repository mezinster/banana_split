/**
 * @jest-environment node
 */
import * as http from "http";
import { AddressInfo } from "net";
import { checkOnce, healthcheck, USER_AGENT } from "../../scripts/healthcheck";

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
  let lastHeaders: http.IncomingHttpHeaders;

  beforeEach(async () => {
    hits = 0;
    responses = [];
    lastHeaders = {};
    server = http.createServer((_req, res) => {
      // Serve each queued response once, then repeat the last one forever.
      lastHeaders = _req.headers;
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

  it("identifies itself with a User-Agent on every request", async () => {
    responses = [
      {
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<html>build " + REVISION + "</html>"
      }
    ];

    await checkOnce(baseUrl, REVISION);

    // Node's http/https send no User-Agent by default, and WAF rulesets such as
    // AWSManagedRulesCommonRuleSet reject that with a 403 — which once caused
    // this healthcheck to roll back two good deploys.
    expect(lastHeaders["user-agent"]).toBe(USER_AGENT);
    expect(lastHeaders["cache-control"]).toBe("no-cache");
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
