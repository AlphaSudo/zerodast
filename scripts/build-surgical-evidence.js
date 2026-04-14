#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = process.argv[2] || process.cwd();
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

function extractAlerts(report) {
  const out = [];
  const sites = Array.isArray(report.site) ? report.site : report.site ? [report.site] : [];
  for (const site of sites) {
    for (const alert of site.alerts || []) {
      out.push({
        pluginid: String(alert.pluginid),
        name: alert.name,
        risk: alert.risk || alert.riskdesc,
      });
    }
  }
  return out;
}

function summarize(dir) {
  const target = path.basename(dir).replace(/^surgical-proof-/, "");
  const reportPath = path.join(dir, "zap-report.json");
  const timingPath = path.join(dir, "timing.json");
  const report = fs.existsSync(reportPath) ? readJson(reportPath) : null;
  const alerts = report ? extractAlerts(report) : [];
  const pluginIds = [...new Set(alerts.map((a) => a.pluginid))].sort();
  let timing = null;
  if (fs.existsSync(timingPath)) timing = readJson(timingPath);

  return {
    target,
    directory: dir,
    image: process.env.ZAP_IMAGE || "unknown",
    alertCount: alerts.length,
    pluginIds,
    hasTimingFile: timing !== null,
  };
}

const dirs = listSurgicalDirs();
const summary = {
  generatedAt: new Date().toISOString(),
  directories: dirs.map(summarize),
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
  "| Target | Alerts | Plugin IDs (unique) |",
  "|--------|--------|---------------------|",
];
for (const row of summary.directories) {
  lines.push(`| ${row.target} | ${row.alertCount} | ${row.pluginIds.length} |`);
}
fs.writeFileSync(outMd, `${lines.join("\n")}\n`, "utf8");
console.error("Wrote", outJson, outMd);
