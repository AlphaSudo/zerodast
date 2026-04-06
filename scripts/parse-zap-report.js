const fs = require("fs");

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

if (!fs.existsSync(reportPath)) {
  console.error(`ZAP report not found: ${reportPath}`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    const risk = normalizeRisk(alert);
    counts[risk] += 1;
  }
}

const markdown = [
  "| Risk | Count |",
  "| --- | ---: |",
  `| Critical | ${counts.critical} |`,
  `| High | ${counts.high} |`,
  `| Medium | ${counts.medium} |`,
  `| Low | ${counts.low} |`,
  `| Informational | ${counts.informational} |`,
].join("\n");

console.log(markdown);
process.exit(shouldFail() ? 1 : 0);
