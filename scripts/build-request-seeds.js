const fs = require("fs");

const [inputPath, targetUrl = "http://untrusted-app:8080"] = process.argv.slice(2);

if (!inputPath) {
  console.error("Usage: node build-request-seeds.js <deltaEndpointsFile> [targetUrl]");
  process.exit(1);
}

const text = fs.readFileSync(inputPath, "utf8");
const lines = text
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);

if (lines[0] === "FULL") {
  process.stdout.write("[]\n");
  process.exit(0);
}

function normalizeEndpoint(endpoint) {
  let normalized = String(endpoint || "").trim();
  if (!normalized) return "";
  normalized = normalized.replace(/\/+$/, "");
  normalized = normalized.replace(/\/:(\w+)/g, "/{$1}");
  return normalized || "/";
}

function concretePath(endpoint) {
  let path = normalizeEndpoint(endpoint);
  path = path.replace(/\{id\}/g, "1");
  path = path.replace(/\{user_id\}/g, "1");
  path = path.replace(/\{document_id\}/g, "1");
  return path;
}

function addSeed(seeds, seen, scope, method, path) {
  const url = `${targetUrl}${path}`;
  const key = `${scope}:${method}:${url}`;
  if (seen.has(key)) return;
  seen.add(key);
  seeds.push({ scope, method, url });
}

function expandEndpoint(endpoint, seeds, seen) {
  const normalized = normalizeEndpoint(endpoint);
  if (!normalized) return;

  const concrete = concretePath(normalized);

  if (normalized === "/health" || normalized === "/v3/api-docs" || normalized === "/api-docs") {
    addSeed(seeds, seen, "public", "GET", concrete);
    return;
  }

  if (normalized === "/api/debug/error") {
    addSeed(seeds, seen, "public", "GET", normalized);
    return;
  }

  if (normalized === "/api/search") {
    addSeed(seeds, seen, "user", "GET", "/api/search?q=roadmap");
    return;
  }

  if (normalized === "/api/search/preview") {
    addSeed(seeds, seen, "public", "GET", "/api/search/preview?q=test");
    return;
  }

  if (normalized === "/api/documents") {
    addSeed(seeds, seen, "user", "GET", "/api/documents");
    return;
  }

  if (normalized.startsWith("/api/documents/")) {
    addSeed(seeds, seen, "user", "GET", concrete);
    return;
  }

  if (normalized === "/api/users") {
    addSeed(seeds, seen, "admin", "GET", "/api/users");
    return;
  }

  if (normalized.startsWith("/api/users/")) {
    addSeed(seeds, seen, "user", "GET", concrete);
    addSeed(seeds, seen, "admin", "GET", "/api/users");
    return;
  }

  if (normalized === "/api/auth/login" || normalized === "/api/auth/register") {
    return;
  }

  addSeed(seeds, seen, normalized.startsWith("/api/") ? "user" : "public", "GET", concrete);
}

const seeds = [];
const seen = new Set();

for (const line of lines) {
  expandEndpoint(line, seeds, seen);
}

process.stdout.write(`${JSON.stringify(seeds, null, 2)}\n`);
