const fs = require("fs");

const registryPath = process.argv[2];
const outJsonPath = process.argv[3];
const outMdPath = process.argv[4];

if (!registryPath || !outJsonPath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-fleet-summary.js <registryPath> <outJsonPath> <outMdPath>"
  );
  process.exit(1);
}

const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const targets = Array.isArray(registry.targets) ? registry.targets : [];

const categoryCounts = {};
const authModeCounts = {};

for (const target of targets) {
  categoryCounts[target.category] = (categoryCounts[target.category] || 0) + 1;
  authModeCounts[target.authMode] = (authModeCounts[target.authMode] || 0) + 1;
}

const summary = {
  generatedAt: new Date().toISOString(),
  counts: {
    targetCount: targets.length,
    categoryCounts,
    authModeCounts,
  },
  targets: targets.map((target) => ({
    id: target.id,
    name: target.name,
    category: target.category,
    repo: target.repo,
    authMode: target.authMode,
    authShapes: target.authShapes || [],
    profilesSupported: target.profilesSupported || [],
    latestProof: target.latestProof || {},
    limitations: target.limitations || [],
  })),
};

const lines = [
  "# Repo Fleet Summary",
  "",
  `- Tracked targets: ${summary.counts.targetCount}`,
  `- Categories tracked: ${Object.keys(summary.counts.categoryCounts).length}`,
  `- Auth modes tracked: ${Object.keys(summary.counts.authModeCounts).length}`,
  "",
  "## Target Matrix",
  "",
  "| Target | Category | Auth Mode | Profiles | Latest Proof | Timing |",
  "| --- | --- | --- | --- | --- | ---: |",
];

for (const target of summary.targets) {
  const profiles = (target.profilesSupported || []).join(", ") || "N/A";
  const proofName = target.latestProof?.workflow || "N/A";
  const proofTiming =
    typeof target.latestProof?.timingSeconds === "number" ? `${target.latestProof.timingSeconds}s` : "N/A";
  lines.push(
    `| ${target.name} | ${target.category} | ${target.authMode} | ${profiles} | ${proofName} | ${proofTiming} |`
  );
}

for (const target of summary.targets) {
  lines.push("", `## ${target.name}`, "");
  lines.push(`- Repo: ${target.repo?.name || "N/A"}`);
  lines.push(`- URL: ${target.repo?.url || "N/A"}`);
  lines.push(`- Category: ${target.category || "N/A"}`);
  lines.push(`- Auth mode: ${target.authMode || "N/A"}`);
  lines.push(`- Auth shapes: ${(target.authShapes || []).join(", ") || "N/A"}`);
  lines.push(`- Profiles supported: ${(target.profilesSupported || []).join(", ") || "N/A"}`);
  lines.push(`- Latest proof workflow: ${target.latestProof?.workflow || "N/A"}`);
  lines.push(`- Latest proof status: ${target.latestProof?.status || "N/A"}`);
  lines.push(
    `- Latest proof timing: ${
      typeof target.latestProof?.timingSeconds === "number" ? `${target.latestProof.timingSeconds}s` : "N/A"
    }`
  );
  if (target.latestProof?.notes) {
    lines.push(`- Latest proof notes: ${target.latestProof.notes}`);
  }
  if ((target.limitations || []).length > 0) {
    lines.push("", "### Known Limitations", "");
    for (const limitation of target.limitations) {
      lines.push(`- ${limitation}`);
    }
  }
}

fs.writeFileSync(outJsonPath, JSON.stringify(summary, null, 2));
fs.writeFileSync(outMdPath, `${lines.join("\n")}\n`);
