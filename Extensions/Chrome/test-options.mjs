#!/usr/bin/env node
// Splynek Accelerator — options-page logic tests.
//
// We test the pure host-sanitization function from options.js.
// The DOM-touching parts (renderList, addHost, removeHost) are
// integration-only and exercised by loading the unpacked extension.
//
// Usage:
//   node Extensions/Chrome/test-options.mjs
//
// Exits 0 on pass, 1 on fail.  No external deps.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const optionsSource = readFileSync(join(here, "options.js"), "utf-8");

// Re-execute options.js with a stub for chrome + window globals so
// we can grab the sanitizeHost function out.  This is a tiny CommonJS-
// style indirect-eval; it's the simplest way to test browser-extension
// JS without pulling in a full bundler.
const sandbox = {
  chrome: {
    storage: { sync: { get(){}, set(){} } },
    runtime: {},
  },
  document: { addEventListener(){}, getElementById(){ return { addEventListener(){} }; } },
  setTimeout: () => {},
  self: {},
};
const fn = new Function(...Object.keys(sandbox), optionsSource + "\nreturn self.sanitizeHost;");
const sanitizeHost = fn(...Object.values(sandbox));

let failures = 0;
function eq(actual, expected, label) {
  const ok = actual === expected;
  console.log(`${ok ? "✓" : "✗"} ${label}  →  ${JSON.stringify(actual)}`);
  if (!ok) {
    failures++;
    console.log(`    expected: ${JSON.stringify(expected)}`);
  }
}

// Bare hostnames pass through.
eq(sanitizeHost("releases.ubuntu.com"), "releases.ubuntu.com", "bare host accepted");
eq(sanitizeHost("github.com"), "github.com", "two-label host accepted");
eq(sanitizeHost("a.b.c.d"), "a.b.c.d", "deep nested host accepted");

// URLs get parsed down to the hostname.
eq(sanitizeHost("https://releases.ubuntu.com/24.04/file.iso"),
   "releases.ubuntu.com", "https URL trimmed to host");
eq(sanitizeHost("http://example.com"),
   "example.com", "http URL trimmed to host");
eq(sanitizeHost("HTTPS://EXAMPLE.COM/path"),
   "example.com", "uppercase URL still lowercased");

// Garbage rejected.
eq(sanitizeHost(""), null, "empty string rejected");
eq(sanitizeHost("   "), null, "whitespace-only rejected");
eq(sanitizeHost("nodot"), null, "no-dot host rejected");
eq(sanitizeHost(".leadingdot.com"), null, "leading dot rejected");
eq(sanitizeHost("trailingdot."), null, "trailing dot rejected");
eq(sanitizeHost("has space.com"), null, "space rejected");
eq(sanitizeHost("special!.com"), null, "special chars rejected");
eq(sanitizeHost("file:///etc/passwd"), null, "non-http URL rejected");

// Edge cases.
eq(sanitizeHost("a.b"), "a.b", "minimal host");
eq(sanitizeHost("UPPER.com"), "upper.com", "case-folded");

if (failures > 0) {
  console.error(`\n✗ ${failures} test(s) failed`);
  process.exit(1);
}
console.log(`\n✓ All sanitizeHost tests passed`);
