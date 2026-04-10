const fs = require("fs");
const path = require("path");

const inputDirs = process.argv.slice(2);

if (inputDirs.length === 0) {
  console.error("Usage: node scripts/extract-route-hints.js <dir> [<dir>...]");
  process.exit(1);
}

const exts = new Set([".js", ".ts", ".py"]);
const routes = new Map();
const routeHintPrefixArgIndex = inputDirs.indexOf("--prefix");
let globalPrefix = "";

if (routeHintPrefixArgIndex !== -1) {
  globalPrefix = inputDirs[routeHintPrefixArgIndex + 1] || "";
  inputDirs.splice(routeHintPrefixArgIndex, 2);
}

function normalizeRoute(route) {
  let normalized = String(route || "").trim();
  if (!normalized) return "";
  if (!normalized.startsWith("/")) normalized = `/${normalized}`;
  normalized = normalized.replace(/\/+$/, "");
  normalized = normalized.replace(/\/:(\w+)/g, "/{$1}");
  normalized = normalized.replace(/\{(\w+)_id\}/g, "{id}");
  return normalized || "/";
}

function addRoute(route, filePath) {
  const normalized = normalizeRoute(route);
  if (!normalized) return;
  if (!routes.has(normalized)) {
    routes.set(normalized, new Set());
  }
  routes.get(normalized).add(filePath);
}

function extractFromText(text, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const jsPattern = /(router|app)\.(get|post|put|delete|patch|options|head)\s*\(\s*["'`]([^"'`]+)["'`]/g;
  const pyRoutePattern = /@[\w.]+\.(get|post|put|delete|patch|options|head)\(\s*["']([^"']+)["']/g;
  const pyPrefixMatches = [...text.matchAll(/APIRouter\([^)]*prefix\s*=\s*["']([^"']+)["']/g)];
  const pyPrefix = pyPrefixMatches.length > 0 ? normalizeRoute(pyPrefixMatches[0][1]) : "";

  if (ext === ".js" || ext === ".ts") {
    for (const match of text.matchAll(jsPattern)) {
      addRoute(match[3], filePath);
    }
  }

  if (ext === ".py") {
    for (const match of text.matchAll(pyRoutePattern)) {
      const route = normalizeRoute(match[2]);
      const combined = pyPrefix
        ? normalizeRoute(route === "/" ? pyPrefix : `${pyPrefix}${route}`)
        : route;
      addRoute(combined, filePath);
    }
  }
}

function walk(dirPath) {
  if (!fs.existsSync(dirPath)) return;
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath);
      continue;
    }
    if (!exts.has(path.extname(entry.name))) {
      continue;
    }
    extractFromText(fs.readFileSync(fullPath, "utf8"), fullPath);
  }
}

for (const dir of inputDirs) {
  walk(path.resolve(dir));
}

const normalizedGlobalPrefix = normalizeRoute(globalPrefix);
const finalRoutes = new Map();

for (const [route, files] of routes.entries()) {
  const finalRoute = normalizedGlobalPrefix
    ? normalizeRoute(route.startsWith(normalizedGlobalPrefix) ? route : `${normalizedGlobalPrefix}${route}`)
    : route;
  if (!finalRoutes.has(finalRoute)) {
    finalRoutes.set(finalRoute, new Set());
  }
  for (const file of files) {
    finalRoutes.get(finalRoute).add(file);
  }
}

const output = {
  generatedAt: new Date().toISOString(),
  globalPrefix: normalizedGlobalPrefix,
  routeCount: finalRoutes.size,
  routes: [...finalRoutes.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([route, files]) => ({
      route,
      files: [...files].sort(),
    })),
};

process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
