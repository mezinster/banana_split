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
