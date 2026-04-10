const fs = require("fs");
const path = require("path");

const reportPath = process.argv[2] || "reports/zap-report.json";
const failLevel = (process.env.ZAP_FAIL_LEVEL || "High").toLowerCase();
const levelOrder = ["critical", "high", "medium", "low", "informational"];
const counts = {
  critical: 0,
  high: 0,
  medium: 0,
  low: 0,
  informational: 0,
};
const reportDir = path.dirname(reportPath);
const logPath = path.join(reportDir, "zap-run.log");
const inventoryJsonPath = path.join(reportDir, "api-inventory.json");
const environmentManifestPath = path.join(reportDir, "environment-manifest.json");
const resultStatePath = path.join(reportDir, "result-state.json");
const deltaPath = path.join("artifacts", "delta-endpoints.txt");
const alertUris = new Set();
const requestorUrls = new Set();
const authRoutePrefixes = ["/api/documents", "/api/search", "/api/users"];
const publicRoutePrefixes = [
  "/health",
  "/v3/api-docs",
  "/api-docs",
  "/api/auth",
  "/api/debug/error",
  "/api/search/preview",
];

/**
 * Resolve risk level from the ZAP alert object.
 * Prefer the numeric riskcode (0=Info,1=Low,2=Medium,3=High) over
 * the textual riskdesc which has the format "Risk (Confidence)" and
 * caused false classification (e.g. "Informational (High)" matched
 * the "high" substring before this fix).
 */
function normalizeRisk(alert) {
  // riskcode is the most reliable source
  const code = Number(alert.riskcode ?? -1);
  if (code >= 0) {
    const codeMap = { 0: "informational", 1: "low", 2: "medium", 3: "high", 4: "critical" };
    if (codeMap[code] !== undefined) return codeMap[code];
  }

  // Fallback to riskdesc text — parse only the part before the parenthesis
  const raw = String(alert.riskdesc || alert.risk || "informational").trim().toLowerCase();
  const riskPart = raw.split("(")[0].trim();

  if (riskPart.includes("critical")) return "critical";
  if (riskPart.includes("high")) return "high";
  if (riskPart.includes("medium")) return "medium";
  if (riskPart.includes("low")) return "low";
  return "informational";
}

function shouldFail() {
  const threshold = levelOrder.indexOf(failLevel);
  const normalizedThreshold = threshold === -1 ? levelOrder.indexOf("high") : threshold;
  return levelOrder.slice(0, normalizedThreshold + 1).some((level) => counts[level] > 0);
}

function normalizeRouteish(value) {
  const raw = String(value || "").trim();
  if (!raw) return "";

  let normalized = raw.replace(/^https?:\/\/[^/]+/i, "");
  normalized = normalized.replace(/\?.*$/, "");
  normalized = normalized.replace(/\/+$/, "");
  normalized = normalized.replace(/\/:(\w+)/g, "/{$1}");
  normalized = normalized.replace(/\/\d+/g, "/{id}");
  normalized = normalized.replace(
    /\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
    "/{id}"
  );
  return normalized || "/";
}

function isPublicRoute(route) {
  return publicRoutePrefixes.some((prefix) => route === prefix || route.startsWith(`${prefix}/`));
}

function isAuthRoute(route) {
  return (
    authRoutePrefixes.some((prefix) => route === prefix || route.startsWith(`${prefix}/`)) &&
    !isPublicRoute(route)
  );
}

function parseDeltaEndpoints() {
  if (!fs.existsSync(deltaPath)) {
    return { mode: "UNAVAILABLE", isFull: false, endpoints: [] };
  }

  const lines = fs
    .readFileSync(deltaPath, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  if (lines[0] === "FULL") {
    return { mode: "FULL", isFull: true, endpoints: [] };
  }

  return {
    mode: "DELTA",
    isFull: false,
    endpoints: [...new Set(lines.map((line) => normalizeRouteish(line)).filter(Boolean))].sort(),
  };
}

function parseRequestorUrls(logText) {
  const urls = new Set();
  for (const line of logText.split(/\r?\n/)) {
    const marker = "Job requestor requesting URL ";
    const idx = line.indexOf(marker);
    if (idx !== -1) {
      urls.add(line.slice(idx + marker.length).trim());
    }
  }
  return urls;
}

if (!fs.existsSync(reportPath)) {
  console.error(`ZAP report not found: ${reportPath}`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const delta = parseDeltaEndpoints();
const logText = fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";

for (const url of parseRequestorUrls(logText)) {
  requestorUrls.add(url);
}

for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    const risk = normalizeRisk(alert);
    counts[risk] += 1;
    for (const instance of alert.instances || []) {
      if (instance.uri) {
        alertUris.add(instance.uri);
      }
    }
  }
}

const normalizedRequestorRoutes = [...new Set([...requestorUrls].map((url) => normalizeRouteish(url)).filter(Boolean))].sort();
const normalizedAlertRoutes = [...new Set([...alertUris].map((url) => normalizeRouteish(url)).filter(Boolean))].sort();
const observedRoutes = new Set([...normalizedRequestorRoutes, ...normalizedAlertRoutes]);
const observedAuthRoutes = normalizedRequestorRoutes.filter((route) => isAuthRoute(route));
const observedPublicRoutes = normalizedRequestorRoutes.filter((route) => isPublicRoute(route));
const observedAdminRoutes = normalizedRequestorRoutes.filter((route) => route === "/api/users" || route.startsWith("/api/users/"));
const deltaObserved = delta.isFull
  ? []
  : delta.endpoints.filter((route) =>
      [...observedRoutes].some((observed) => observed === route || observed.startsWith(`${route}/`) || route.startsWith(`${observed}/`))
    );
const deltaMissed = delta.isFull ? [] : delta.endpoints.filter((route) => !deltaObserved.includes(route));

const markdown = [
  "| Risk | Count |",
  "| --- | ---: |",
  `| Critical | ${counts.critical} |`,
  `| High | ${counts.high} |`,
  `| Medium | ${counts.medium} |`,
  `| Low | ${counts.low} |`,
  `| Informational | ${counts.informational} |`,
  "",
  "## Scan Signal",
  "",
  `- Delta mode: ${delta.mode}`,
  `- Requestor URL count: ${requestorUrls.size}`,
  `- Observed route count (requestor + alert instances): ${observedRoutes.size}`,
  `- Observed authenticated requestor routes: ${observedAuthRoutes.length}`,
  `- Observed public requestor routes: ${observedPublicRoutes.length}`,
  `- Observed admin requestor routes: ${observedAdminRoutes.length}`,
  `- Alert-bearing URI count: ${alertUris.size}`,
].join("\n");

console.log(markdown);

if (fs.existsSync(environmentManifestPath)) {
  const manifest = JSON.parse(fs.readFileSync(environmentManifestPath, "utf8"));
  console.log("");
  console.log("## Operator Context");
  console.log("");
  console.log(`- Target name: ${manifest.target?.name || "N/A"}`);
  console.log(`- Scan profile: ${manifest.scan?.profile || "N/A"}`);
  console.log(`- Scan trigger: ${manifest.scan?.trigger || "N/A"}`);
  console.log(`- Auth bootstrap mode: ${manifest.auth?.bootstrapMode || "N/A"}`);
}

if (fs.existsSync(resultStatePath)) {
  const state = JSON.parse(fs.readFileSync(resultStatePath, "utf8"));
  console.log("");
  console.log("## Result State");
  console.log("");
  console.log(`- State: ${state.state}`);
  console.log(`- Fail level: ${state.failLevel}`);
  console.log(`- Suppressed alert count: ${state.counts?.suppressedAlertCount ?? 0}`);
  console.log(`- Unique suppression rules applied: ${state.counts?.uniqueSuppressionCount ?? 0}`);
  console.log(`- Effective high-or-above findings: ${(state.counts?.effective?.critical ?? 0) + (state.counts?.effective?.high ?? 0)}`);
}

if (fs.existsSync(inventoryJsonPath)) {
  const inventory = JSON.parse(fs.readFileSync(inventoryJsonPath, "utf8"));
  const counts = inventory.counts || {};
  console.log("");
  console.log("## API Inventory");
  console.log("");
  console.log(`- OpenAPI route count: ${counts.openApiRouteCount ?? 0}`);
  console.log(`- OpenAPI operation count: ${counts.openApiOperationCount ?? 0}`);
  console.log(`- OpenAPI imported URL count: ${counts.openApiImportedUrlCount ?? 0}`);
  console.log(`- Spider discovered URL count: ${counts.spiderDiscoveredUrlCount ?? 0}`);
  console.log(`- Observed OpenAPI routes: ${counts.observedSpecRouteCount ?? 0}`);
  console.log(`- Unobserved OpenAPI routes: ${counts.unobservedSpecRouteCount ?? 0}`);
  console.log(`- Undocumented observed routes: ${counts.undocumentedObservedRouteCount ?? 0}`);
  console.log(`- Code-hinted routes: ${counts.hintedRouteCount ?? 0}`);
  console.log(`- Code-hinted observed routes: ${counts.hintedObservedRouteCount ?? 0}`);
  console.log(`- Code-hinted unobserved routes: ${counts.hintedUnobservedRouteCount ?? 0}`);
  console.log(`- Code-hinted routes outside spec: ${counts.hintedOnlyRouteCount ?? 0}`);

  if (Array.isArray(inventory.undocumentedObservedRoutes) && inventory.undocumentedObservedRoutes.length > 0) {
    console.log("");
    console.log("### Undocumented Observed Routes");
    console.log("");
    for (const route of inventory.undocumentedObservedRoutes.slice(0, 12)) {
      console.log(`- ${route}`);
    }
  }

  if (Array.isArray(inventory.hintedUnobservedRoutes) && inventory.hintedUnobservedRoutes.length > 0) {
    console.log("");
    console.log("### Code-Hinted Unobserved Routes");
    console.log("");
    for (const route of inventory.hintedUnobservedRoutes.slice(0, 12)) {
      console.log(`- ${route}`);
    }
  }

  if (Array.isArray(inventory.hintedOnlyRoutes) && inventory.hintedOnlyRoutes.length > 0) {
    console.log("");
    console.log("### Code-Hinted Routes Outside Spec");
    console.log("");
    for (const route of inventory.hintedOnlyRoutes.slice(0, 12)) {
      console.log(`- ${route}`);
    }
  }
}

if (delta.mode === "DELTA") {
  if (delta.endpoints.length > 0) {
    console.log("");
    console.log("## Delta Coverage");
    console.log("");
    console.log(`- Delta endpoint count: ${delta.endpoints.length}`);
    console.log(`- Delta endpoints observed: ${deltaObserved.length}`);
    console.log(`- Delta endpoints not observed: ${deltaMissed.length}`);
  }

  if (deltaObserved.length > 0) {
    console.log("");
    console.log("### Observed Delta Endpoints");
    console.log("");
    for (const route of deltaObserved) {
      console.log(`- ${route}`);
    }
  }

  if (deltaMissed.length > 0) {
    console.log("");
    console.log("### Unobserved Delta Endpoints");
    console.log("");
    for (const route of deltaMissed) {
      console.log(`- ${route}`);
    }
  }
}

if (normalizedRequestorRoutes.length > 0) {
  console.log("");
  console.log("## Requestor Routes");
  console.log("");
  for (const route of normalizedRequestorRoutes) {
    console.log(`- ${route}`);
  }
}

process.exit(shouldFail() ? 1 : 0);
