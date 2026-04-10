const fs = require("fs");
const path = require("path");

const reportPath = process.argv[2];
const logPath = process.argv[3];
const specPath = process.argv[4];
const outJsonPath = process.argv[5];
const outMdPath = process.argv[6];
const routeHintsPath = process.argv[7];
const stripPrefixArg = process.argv[8] || "";

if (!reportPath || !logPath || !specPath || !outJsonPath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-api-inventory.js <reportPath> <logPath> <specPath> <outJsonPath> <outMdPath> [routeHintsJsonPath]"
  );
  process.exit(1);
}

function normalizeRouteish(value) {
  const raw = String(value || "").trim();
  if (!raw) return "";

  let normalized = raw.replace(/^https?:\/\/[^/]+/i, "");
  if (stripPrefixArg) {
    const normalizedStripPrefix = String(stripPrefixArg).replace(/\/+$/, "");
    if (normalized === normalizedStripPrefix) {
      normalized = "/";
    } else if (normalized.startsWith(`${normalizedStripPrefix}/`)) {
      normalized = normalized.slice(normalizedStripPrefix.length);
    }
  }
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

function parseSpiderCount(logText) {
  const matches = [...logText.matchAll(/Job spider found (\d+) URLs/g)];
  if (matches.length === 0) return 0;
  return Number(matches[matches.length - 1][1] || 0);
}

function parseOpenApiImportedCount(logText) {
  const matches = [...logText.matchAll(/Job openapi added (\d+) URLs/g)];
  if (matches.length === 0) return 0;
  return Number(matches[matches.length - 1][1] || 0);
}

function routesOverlap(left, right) {
  return left === right || left.startsWith(`${right}/`) || right.startsWith(`${left}/`);
}

function loadSpecRoutes(specFilePath) {
  if (!fs.existsSync(specFilePath)) {
    return { routes: [], operations: 0 };
  }

  const raw = JSON.parse(fs.readFileSync(specFilePath, "utf8"));
  const routes = [];
  let operations = 0;

  for (const [specPathValue, methods] of Object.entries(raw.paths || {})) {
    const normalizedRoute = normalizeRouteish(specPathValue);
    routes.push(normalizedRoute);
    operations += Object.keys(methods || {}).filter((method) =>
      ["get", "post", "put", "patch", "delete", "options", "head"].includes(method.toLowerCase())
    ).length;
  }

  return {
    routes: [...new Set(routes)].sort(),
    operations,
  };
}

function loadRouteHints(hintsFilePath) {
  if (!hintsFilePath || !fs.existsSync(hintsFilePath)) {
    return [];
  }
  const raw = JSON.parse(fs.readFileSync(hintsFilePath, "utf8"));
  return [...new Set((raw.routes || []).map((entry) => normalizeRouteish(entry.route)).filter(Boolean))].sort();
}

const report = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath, "utf8")) : { site: [] };
const logText = fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";
const spec = loadSpecRoutes(specPath);
const routeHints = loadRouteHints(routeHintsPath);

const alertRoutes = new Set();
for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    for (const instance of alert.instances || []) {
      if (instance.uri) {
        alertRoutes.add(normalizeRouteish(instance.uri));
      }
    }
  }
}

const requestorRoutes = new Set([...parseRequestorUrls(logText)].map((url) => normalizeRouteish(url)).filter(Boolean));
const observedRoutes = new Set([...requestorRoutes, ...alertRoutes]);
const observedSpecRoutes = spec.routes.filter((route) =>
  [...observedRoutes].some(
    (observed) => routesOverlap(observed, route)
  )
);
const unobservedSpecRoutes = spec.routes.filter((route) => !observedSpecRoutes.includes(route));
const undocumentedObservedRoutes = [...observedRoutes]
  .filter((observed) => !spec.routes.some((route) => routesOverlap(observed, route)))
  .sort();
const hintedObservedRoutes = routeHints.filter((route) =>
  [...observedRoutes].some((observed) => routesOverlap(observed, route))
);
const hintedUnobservedRoutes = routeHints.filter((route) => !hintedObservedRoutes.includes(route));
const hintedOnlyRoutes = routeHints.filter(
  (route) => !spec.routes.some((specRoute) => routesOverlap(specRoute, route))
);

const inventory = {
  generatedAt: new Date().toISOString(),
  sourceFiles: {
    reportPath: path.basename(reportPath),
    logPath: path.basename(logPath),
    specPath: path.basename(specPath),
  },
  counts: {
    openApiRouteCount: spec.routes.length,
    openApiOperationCount: spec.operations,
    openApiImportedUrlCount: parseOpenApiImportedCount(logText),
    spiderDiscoveredUrlCount: parseSpiderCount(logText),
    requestorRouteCount: requestorRoutes.size,
    alertRouteCount: alertRoutes.size,
    observedRouteCount: observedRoutes.size,
    observedSpecRouteCount: observedSpecRoutes.length,
    unobservedSpecRouteCount: unobservedSpecRoutes.length,
    undocumentedObservedRouteCount: undocumentedObservedRoutes.length,
    hintedRouteCount: routeHints.length,
    hintedObservedRouteCount: hintedObservedRoutes.length,
    hintedUnobservedRouteCount: hintedUnobservedRoutes.length,
    hintedOnlyRouteCount: hintedOnlyRoutes.length,
  },
  openApiRoutes: spec.routes,
  requestorRoutes: [...requestorRoutes].sort(),
  alertRoutes: [...alertRoutes].sort(),
  observedSpecRoutes,
  unobservedSpecRoutes,
  undocumentedObservedRoutes,
  hintedRoutes: routeHints,
  hintedObservedRoutes,
  hintedUnobservedRoutes,
  hintedOnlyRoutes,
};

const markdown = [
  "## API Inventory",
  "",
  `- OpenAPI route count: ${inventory.counts.openApiRouteCount}`,
  `- OpenAPI operation count: ${inventory.counts.openApiOperationCount}`,
  `- OpenAPI imported URL count: ${inventory.counts.openApiImportedUrlCount}`,
  `- Spider discovered URL count: ${inventory.counts.spiderDiscoveredUrlCount}`,
  `- Requestor route count: ${inventory.counts.requestorRouteCount}`,
  `- Alert route count: ${inventory.counts.alertRouteCount}`,
  `- Observed route count: ${inventory.counts.observedRouteCount}`,
  `- Observed OpenAPI routes: ${inventory.counts.observedSpecRouteCount}`,
  `- Unobserved OpenAPI routes: ${inventory.counts.unobservedSpecRouteCount}`,
  `- Undocumented observed routes: ${inventory.counts.undocumentedObservedRouteCount}`,
  `- Code-hinted routes: ${inventory.counts.hintedRouteCount}`,
  `- Code-hinted observed routes: ${inventory.counts.hintedObservedRouteCount}`,
  `- Code-hinted unobserved routes: ${inventory.counts.hintedUnobservedRouteCount}`,
  `- Code-hinted routes outside spec: ${inventory.counts.hintedOnlyRouteCount}`,
];

if (inventory.unobservedSpecRoutes.length > 0) {
  markdown.push("", "### Unobserved OpenAPI Routes", "");
  for (const route of inventory.unobservedSpecRoutes) {
    markdown.push(`- ${route}`);
  }
}

if (inventory.undocumentedObservedRoutes.length > 0) {
  markdown.push("", "### Undocumented Observed Routes", "");
  for (const route of inventory.undocumentedObservedRoutes) {
    markdown.push(`- ${route}`);
  }
}

if (inventory.hintedUnobservedRoutes.length > 0) {
  markdown.push("", "### Code-Hinted Unobserved Routes", "");
  for (const route of inventory.hintedUnobservedRoutes) {
    markdown.push(`- ${route}`);
  }
}

if (inventory.hintedOnlyRoutes.length > 0) {
  markdown.push("", "### Code-Hinted Routes Outside Spec", "");
  for (const route of inventory.hintedOnlyRoutes) {
    markdown.push(`- ${route}`);
  }
}

fs.writeFileSync(outJsonPath, `${JSON.stringify(inventory, null, 2)}\n`);
fs.writeFileSync(outMdPath, `${markdown.join("\n")}\n`);
