const fs = require("fs");

const outJsonPath = process.argv[2];
const outMdPath = process.argv[3];

if (!outJsonPath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-environment-manifest.js <outJsonPath> <outMdPath>"
  );
  process.exit(1);
}

function readEnv(name, fallback = "") {
  return String(process.env[name] || fallback).trim();
}

function splitList(value) {
  return String(value || "")
    .split(/\s+/)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

const manifest = {
  target: {
    name: readEnv("ZERODAST_TARGET_NAME", "zerodast-demo-app"),
    appUrl: readEnv("AUTH_BOOTSTRAP_URL", "http://127.0.0.1:8080"),
    healthPath: readEnv("APP_HEALTH_PATH", "/health"),
    openApiSpecUrl: readEnv("OPENAPI_SPEC_URL", ""),
  },
  scan: {
    profile: readEnv("ZERODAST_SCAN_PROFILE", "full"),
    trigger: readEnv("ZERODAST_SCAN_TRIGGER", "local"),
    mode: readEnv("ZERODAST_SCAN_MODE", "core"),
    failLevel: readEnv("ZAP_FAIL_LEVEL", "High"),
    zapVersion: readEnv("ZAP_VERSION", "2.17.0"),
    configPath: readEnv("ZAP_CONFIG_PATH", ""),
  },
  auth: {
    bootstrapMode: readEnv("AUTH_BOOTSTRAP_MODE", ""),
    adapterScript: readEnv("AUTH_ADAPTER_SCRIPT", ""),
    protectedRoutePath: readEnv("AUTH_PROTECTED_ROUTE_PATH", ""),
    adminProtectedRoutePath: readEnv("ADMIN_PROTECTED_ROUTE_PATH", ""),
  },
  routeHints: {
    sourceDirs: splitList(readEnv("ROUTE_HINT_DIRS", "")),
  },
};

const markdown = [
  "# Scan Environment Manifest",
  "",
  `- Target name: ${manifest.target.name}`,
  `- App URL: ${manifest.target.appUrl || "N/A"}`,
  `- Health path: ${manifest.target.healthPath || "N/A"}`,
  `- OpenAPI spec URL: ${manifest.target.openApiSpecUrl || "N/A"}`,
  `- Scan profile: ${manifest.scan.profile}`,
  `- Scan trigger: ${manifest.scan.trigger}`,
  `- Scan mode: ${manifest.scan.mode}`,
  `- Fail level: ${manifest.scan.failLevel}`,
  `- ZAP version: ${manifest.scan.zapVersion}`,
  `- Auth bootstrap mode: ${manifest.auth.bootstrapMode || "N/A"}`,
  `- Auth adapter script: ${manifest.auth.adapterScript || "N/A"}`,
  `- Protected route path: ${manifest.auth.protectedRoutePath || "N/A"}`,
  `- Admin protected route path: ${manifest.auth.adminProtectedRoutePath || "N/A"}`,
  `- Route hint source dirs: ${manifest.routeHints.sourceDirs.length > 0 ? manifest.routeHints.sourceDirs.join(", ") : "N/A"}`,
].join("\n");

fs.writeFileSync(outJsonPath, JSON.stringify(manifest, null, 2));
fs.writeFileSync(outMdPath, `${markdown}\n`);
