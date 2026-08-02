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
