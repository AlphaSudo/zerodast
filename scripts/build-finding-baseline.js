const fs = require("fs");

const reportPath = process.argv[2];
const suppressionPath = process.argv[3];
const outJsonPath = process.argv[4];

if (!reportPath || !suppressionPath || !outJsonPath) {
  console.error(
    "Usage: node scripts/build-finding-baseline.js <reportPath> <suppressionPath> <outJsonPath>"
  );
  process.exit(1);
}

function normalizeRisk(alert) {
  const code = Number(alert.riskcode ?? -1);
  if (code >= 0) {
    const codeMap = { 0: "informational", 1: "low", 2: "medium", 3: "high", 4: "critical" };
    if (codeMap[code] !== undefined) return codeMap[code];
  }

  const raw = String(alert.riskdesc || alert.risk || "informational").trim().toLowerCase();
  const riskPart = raw.split("(")[0].trim();
  if (riskPart.includes("critical")) return "critical";
  if (riskPart.includes("high")) return "high";
  if (riskPart.includes("medium")) return "medium";
  if (riskPart.includes("low")) return "low";
  return "informational";
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

function loadSuppressions(filePath) {
  if (!fs.existsSync(filePath)) {
    return [];
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8")).suppressions || [];
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const suppressions = loadSuppressions(suppressionPath);
const signatures = [];
const seen = new Set();

for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    const risk = normalizeRisk(alert);
    const suppression = suppressions.find((entry) => {
      const sameName = String(entry.name || "").trim() === String(alert.name || "").trim();
      const sameRisk =
        !entry.risk || String(entry.risk).trim().toLowerCase() === String(risk).trim().toLowerCase();
      return sameName && sameRisk;
    });

    if (suppression) {
      continue;
    }

    const routes =
      Array.isArray(alert.instances) && alert.instances.length > 0
        ? alert.instances.map((instance) => normalizeRouteish(instance.uri)).filter(Boolean)
        : [normalizeRouteish(site["@name"] || site.name || "/")];

    for (const route of routes) {
      const signature = {
        name: String(alert.name || "").trim(),
        risk,
        route,
      };
      const key = `${signature.risk}::${signature.name}::${signature.route}`;
      if (!seen.has(key)) {
        seen.add(key);
        signatures.push(signature);
      }
    }
  }
}

const baseline = {
  version: 1,
  generatedAt: new Date().toISOString(),
  sourceReport: reportPath,
  signatures: signatures.sort((a, b) =>
    `${a.risk}::${a.name}::${a.route}`.localeCompare(`${b.risk}::${b.name}::${b.route}`)
  ),
};

fs.writeFileSync(outJsonPath, JSON.stringify(baseline, null, 2));
