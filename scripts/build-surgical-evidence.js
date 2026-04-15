#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = process.cwd();
const requestedRoot = process.argv[2];

if (requestedRoot && path.resolve(requestedRoot) !== ROOT) {
  console.error("build-surgical-evidence.js runs relative to the current working directory; cd to the repo root before invoking it.");
  process.exit(1);
}

const REPORTS = path.join(ROOT, "reports");

function listSurgicalDirs() {
  if (!fs.existsSync(REPORTS)) return [];
  return fs
    .readdirSync(REPORTS)
    .filter((name) => name.startsWith("surgical-proof-"))
    .map((name) => path.join(REPORTS, name));
}

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

function readText(p) {
  try {
    return fs.readFileSync(p, "utf8");
  } catch {
    return "";
  }
}

function extractAlerts(report) {
  const out = [];
  const sites = Array.isArray(report.site) ? report.site : report.site ? [report.site] : [];
  for (const site of sites) {
    for (const alert of site.alerts || []) {
      out.push({
        pluginid: String(alert.pluginid),
        name: alert.name,
        riskcode: Number.parseInt(alert.riskcode, 10) || 0,
        risk: alert.risk || alert.riskdesc,
        count: Number.parseInt(alert.count, 10) || 0,
        uris: [...new Set((alert.instances || []).map((instance) => instance.uri).filter(Boolean))].sort(),
      });
    }
  }
  return out;
}

function countLines(text) {
  if (!text.trim()) return 0;
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean).length;
}

function parseMemToMiB(sample) {
  const match = sample.match(/([0-9.]+)\s*([KMG]i?)?B/i);
  if (!match) return null;

  const value = Number.parseFloat(match[1]);
  const unit = (match[2] || "B").toUpperCase();
  if (Number.isNaN(value)) return null;

  if (unit.startsWith("G")) return value * 1024;
  if (unit.startsWith("M")) return value;
  if (unit.startsWith("K")) return value / 1024;
  return value / (1024 * 1024);
}

function parseMemorySamples(text) {
  const samples = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const current = line.split("/")[0].trim();
      return parseMemToMiB(current);
    })
    .filter((value) => value !== null);

  if (samples.length === 0) {
    return {
      sampleCount: 0,
      peakMemMiB: null,
    };
  }

  return {
    sampleCount: samples.length,
    peakMemMiB: Math.max(...samples),
  };
}

function buildAlertSignatures(report) {
  return new Set(
    extractAlerts(report)
      .filter((alert) => alert.riskcode >= 2)
      .map((alert) =>
        [
          alert.pluginid,
          alert.name,
          alert.riskcode,
          alert.count,
          alert.uris.join(","),
        ].join("\t")
      )
  );
}

function buildAlertTypeSignatures(report) {
  return new Set(
    extractAlerts(report)
      .filter((alert) => alert.riskcode >= 2)
      .map((alert) =>
        [
          alert.pluginid,
          alert.name,
          alert.riskcode,
          alert.risk,
        ].join("\t")
      )
  );
}

function diffSets(left, right) {
  return [...left].filter((value) => !right.has(value)).sort();
}

function compareAgainstFrozenStock(target, report) {
  const frozenPath = path.join(ROOT, `tmp-ci-proof-${target}`, "zap-report.json");
  if (!fs.existsSync(frozenPath) || !report) {
    return {
      comparedToFrozenStock: false,
      frozenStockPath: frozenPath,
      missingMediumPlusAlerts: [],
      extraMediumPlusAlerts: [],
      mediumPlusParity: null,
    };
  }

  const frozenReport = readJson(frozenPath);
  if (!frozenReport) {
    return {
      comparedToFrozenStock: false,
      frozenStockPath: frozenPath,
      missingMediumPlusAlerts: [],
      extraMediumPlusAlerts: [],
      mediumPlusParity: null,
    };
  }

  const stockTypeSet = buildAlertTypeSignatures(frozenReport);
  const surgicalTypeSet = buildAlertTypeSignatures(report);
  const missing = diffSets(stockTypeSet, surgicalTypeSet);
  const extra = diffSets(surgicalTypeSet, stockTypeSet);

  return {
    comparedToFrozenStock: true,
    frozenStockPath: frozenPath,
    missingMediumPlusAlerts: missing,
    extraMediumPlusAlerts: extra,
    mediumPlusParity: missing.length === 0,
  };
}

function summarize(dir) {
  const target = path.basename(dir).replace(/^surgical-proof-/, "");
  const reportPath = path.join(dir, "zap-report.json");
  const timingPath = path.join(dir, "timing.json");
  const metricsPath = path.join(dir, "metrics.json");
  const addonInventoryPath = path.join(dir, "installed-addon-inventory.txt");
  const memorySamplesPath = path.join(dir, "memory-samples.txt");
  const report = fs.existsSync(reportPath) ? readJson(reportPath) : null;
  const alerts = report ? extractAlerts(report) : [];
  const pluginIds = [...new Set(alerts.map((a) => a.pluginid))].sort();
  const timing = fs.existsSync(timingPath) ? readJson(timingPath) : null;
  const metrics = fs.existsSync(metricsPath) ? readJson(metricsPath) : null;
  const addonInventoryText = readText(addonInventoryPath);
  const memoryInfo = parseMemorySamples(readText(memorySamplesPath));
  const frozenComparison = compareAgainstFrozenStock(target, report);

  return {
    target,
    directory: dir,
    image: timing?.image || process.env.ZAP_IMAGE || "unknown",
    alertEntryCount: alerts.length,
    alertInstanceCount: alerts.reduce((sum, alert) => sum + alert.count, 0),
    pluginIds,
    pluginIdCount: pluginIds.length,
    hasTimingFile: timing !== null,
    benchmarkSeconds: timing?.seconds ?? null,
    coldRunSeconds: metrics?.coldRunSeconds ?? null,
    installedAddonCount: countLines(addonInventoryText),
    hasInstalledAddonInventory: Boolean(addonInventoryText.trim()),
    memorySampleCount: memoryInfo.sampleCount,
    peakMemMiB: memoryInfo.peakMemMiB,
    ...frozenComparison,
  };
}

const dirs = listSurgicalDirs();
const summary = {
  generatedAt: new Date().toISOString(),
  targets: dirs.map(summarize),
};

const outJson = path.join(REPORTS, "surgical-evidence-summary.json");
const outMd = path.join(REPORTS, "surgical-evidence-summary.md");
fs.mkdirSync(REPORTS, { recursive: true });
fs.writeFileSync(outJson, JSON.stringify(summary, null, 2), "utf8");

const lines = [
  "# Surgical scan evidence summary",
  "",
  `Generated: ${summary.generatedAt}`,
  "",
  "| Target | Alert entries | Alert instances | Plugin IDs | Cold run (s) | Peak mem (MiB) | Installed addons | Medium+ parity vs frozen stock |",
  "|--------|---------------|-----------------|------------|--------------|----------------|------------------|-------------------------------|",
];
for (const row of summary.targets) {
  lines.push(
    `| ${row.target} | ${row.alertEntryCount} | ${row.alertInstanceCount} | ${row.pluginIdCount} | ${row.coldRunSeconds ?? "n/a"} | ${row.peakMemMiB !== null ? row.peakMemMiB.toFixed(1) : "n/a"} | ${row.installedAddonCount || "n/a"} | ${row.mediumPlusParity === null ? "n/a" : row.mediumPlusParity ? "PASS" : "FAIL"} |`
  );
}

lines.push("");
lines.push("## Notes");
lines.push("");
lines.push("- `Installed addons` counts lines in `installed-addon-inventory.txt` when present.");
lines.push("- `Medium+ parity vs frozen stock` compares against `tmp-ci-proof-<target>/zap-report.json` when available.");
lines.push("- `Alert entries` is the number of top-level ZAP alert objects; `Alert instances` sums each alert's instance count.");

for (const row of summary.targets) {
  if (row.mediumPlusParity === false) {
    lines.push("");
    lines.push(`### ${row.target} parity gaps`);
    lines.push("");
    lines.push("Missing Medium+ alerts:");
    lines.push("");
    for (const item of row.missingMediumPlusAlerts) {
      lines.push(`- ${item}`);
    }
    if (row.extraMediumPlusAlerts.length > 0) {
      lines.push("");
      lines.push("Extra Medium+ alerts:");
      lines.push("");
      for (const item of row.extraMediumPlusAlerts) {
        lines.push(`- ${item}`);
      }
    }
  }
}
fs.writeFileSync(outMd, `${lines.join("\n")}\n`, "utf8");
console.error("Wrote", outJson, outMd);
