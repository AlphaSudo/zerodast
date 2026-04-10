const fs = require("fs");

const reportPath = process.argv[2];
const baselinePath = process.argv[3];
const outJsonPath = process.argv[4];
const outMdPath = process.argv[5];

if (!reportPath || !baselinePath || !outJsonPath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-result-state.js <reportPath> <baselinePath> <outJsonPath> <outMdPath>"
  );
  process.exit(1);
}

const failLevel = (process.env.ZAP_FAIL_LEVEL || "High").toLowerCase();
const levelOrder = ["critical", "high", "medium", "low", "informational"];

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

function emptyCounts() {
  return {
    critical: 0,
    high: 0,
    medium: 0,
    low: 0,
    informational: 0,
  };
}

function exceedsThreshold(counts) {
  const threshold = levelOrder.indexOf(failLevel);
  const normalizedThreshold = threshold === -1 ? levelOrder.indexOf("high") : threshold;
  return levelOrder.slice(0, normalizedThreshold + 1).some((level) => counts[level] > 0);
}

function loadBaseline(filePath) {
  if (!fs.existsSync(filePath)) {
    return { suppressions: [] };
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const baseline = loadBaseline(baselinePath);
const rawCounts = emptyCounts();
const effectiveCounts = emptyCounts();
const appliedSuppressions = [];

for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    const risk = normalizeRisk(alert);
    rawCounts[risk] += 1;

    const suppression = (baseline.suppressions || []).find((entry) => {
      const sameName = String(entry.name || "").trim() === String(alert.name || "").trim();
      const sameRisk =
        !entry.risk || String(entry.risk).trim().toLowerCase() === String(risk).trim().toLowerCase();
      return sameName && sameRisk;
    });

    if (suppression) {
      appliedSuppressions.push({
        name: String(alert.name || "").trim(),
        risk,
        reason: String(suppression.reason || "").trim(),
      });
      continue;
    }

    effectiveCounts[risk] += 1;
  }
}

const uniqueSuppressions = [];
const seenSuppressionKeys = new Set();
for (const suppression of appliedSuppressions) {
  const key = `${suppression.name}::${suppression.risk}::${suppression.reason}`;
  if (!seenSuppressionKeys.has(key)) {
    seenSuppressionKeys.add(key);
    uniqueSuppressions.push(suppression);
  }
}

const state = exceedsThreshold(effectiveCounts)
  ? "needs_triage"
  : uniqueSuppressions.length > 0
    ? "baseline_only"
    : "clean";

const result = {
  state,
  failLevel,
  counts: {
    raw: rawCounts,
    effective: effectiveCounts,
    suppressedAlertCount: appliedSuppressions.length,
    uniqueSuppressionCount: uniqueSuppressions.length,
  },
  suppressionsApplied: uniqueSuppressions,
  triage: {
    action:
      state === "needs_triage"
        ? "Review active findings and decide remediation or acceptance."
        : state === "baseline_only"
          ? "Review only if baseline suppressions should change."
          : "No active findings above the current baseline.",
  },
};

const markdown = [
  "# Result State",
  "",
  `- State: ${result.state}`,
  `- Fail level: ${result.failLevel}`,
  `- Suppressed alert count: ${result.counts.suppressedAlertCount}`,
  `- Unique suppression rules applied: ${result.counts.uniqueSuppressionCount}`,
  "",
  "## Effective Counts",
  "",
  `- Critical: ${result.counts.effective.critical}`,
  `- High: ${result.counts.effective.high}`,
  `- Medium: ${result.counts.effective.medium}`,
  `- Low: ${result.counts.effective.low}`,
  `- Informational: ${result.counts.effective.informational}`,
  "",
  "## Triage Guidance",
  "",
  `- ${result.triage.action}`,
];

if (uniqueSuppressions.length > 0) {
  markdown.push("", "## Applied Suppressions", "");
  for (const suppression of uniqueSuppressions.slice(0, 20)) {
    markdown.push(`- ${suppression.name} (${suppression.risk}): ${suppression.reason || "No reason provided"}`);
  }
}

fs.writeFileSync(outJsonPath, JSON.stringify(result, null, 2));
fs.writeFileSync(outMdPath, `${markdown.join("\n")}\n`);
