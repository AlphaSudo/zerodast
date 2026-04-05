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

function normalizeRisk(value) {
  const text = String(value || "informational").trim().toLowerCase();
  if (text.includes("critical")) return "critical";
  if (text.includes("high")) return "high";
  if (text.includes("medium")) return "medium";
  if (text.includes("low")) return "low";
  if (text.includes("info")) return "informational";
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
    const risk = normalizeRisk(alert.riskdesc || alert.risk || alert.riskcode);
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
