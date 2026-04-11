const fs = require("fs");

const resultStatePath = process.argv[2];
const outMdPath = process.argv[3];

if (!resultStatePath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-remediation-guide.js <resultStatePath> <outMdPath>"
  );
  process.exit(1);
}

const resultState = JSON.parse(fs.readFileSync(resultStatePath, "utf8"));
const comparison = resultState.comparison || {};
const newFindings = comparison.newFindings || [];
const persistingFindings = comparison.persistingFindings || [];
const resolvedFindings = comparison.resolvedFindings || [];

function topRisk(findings) {
  const order = ["critical", "high", "medium", "low", "informational"];
  const found = findings
    .map((finding) => String(finding.risk || "informational").toLowerCase())
    .sort((a, b) => order.indexOf(a) - order.indexOf(b));
  return found[0] || "none";
}

function renderFindingList(title, findings, limit = 12) {
  if (!findings.length) {
    return [`## ${title}`, "", "- None", ""];
  }

  return [
    `## ${title}`,
    "",
    ...findings.slice(0, limit).map((finding) => `- ${finding.name} (${finding.risk}) on ${finding.route}`),
    "",
  ];
}

const prioritySummary =
  newFindings.length > 0
    ? `Prioritize ${newFindings.length} new finding(s) first, top risk: ${topRisk(newFindings)}.`
    : persistingFindings.length > 0
      ? `No new findings; focus on ${persistingFindings.length} persisting finding(s), top risk: ${topRisk(persistingFindings)}.`
      : "No active findings above the current baseline.";

const retestTargets = newFindings.length > 0 ? newFindings : persistingFindings;

const lines = [
  "# Remediation and Retest Guide",
  "",
  `- Current state: ${resultState.state}`,
  `- Priority summary: ${prioritySummary}`,
  "",
  "## Recommended Order",
  "",
  newFindings.length > 0
    ? "- Fix newly introduced findings before spending time on older persisting findings."
    : "- No new findings were introduced; work down the persisting findings list by risk.",
  "- After each fix, rerun the same PR or nightly profile and compare `new/persisting/resolved` counts.",
  "- Treat a finding as fully closed only when it moves out of `new`/`persisting` and appears under `resolved` or disappears from active results.",
  "",
  ...renderFindingList("New Findings to Triage First", newFindings),
  ...renderFindingList("Persisting Findings to Retest After Fixes", persistingFindings),
  ...renderFindingList("Recently Resolved Findings to Guard", resolvedFindings, 8),
  "## Retest Guidance",
  "",
  retestTargets.length > 0
    ? `- After fixing a route, verify the next run still exercises it and check that the relevant entry disappears from \`new\`/ \`persisting\`.`
    : "- No active retest targets right now.",
  "- Keep the baseline file stable unless you intentionally change what counts as accepted demo noise.",
  "- If a finding moves from `new` to `persisting`, treat that as accepted debt only with an explicit decision.",
  "",
];

fs.writeFileSync(outMdPath, `${lines.join("\n")}\n`);
