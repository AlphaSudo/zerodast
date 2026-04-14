#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const YAML = require("yaml");

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--base") out.base = argv[++i];
    else if (a === "--profile") out.profile = argv[++i];
    else if (a === "--rest-base") out.restBase = argv[++i];
    else if (a === "--output") out.output = argv[++i];
  }
  return out;
}

function loadYaml(p) {
  return YAML.parse(fs.readFileSync(p, "utf8"));
}

function deepMergePolicyRules(baseRules, overrides) {
  const byId = new Map();
  for (const r of baseRules || []) {
    if (r && r.id !== undefined) byId.set(Number(r.id), { ...r });
  }
  for (const r of overrides || []) {
    if (r && r.id !== undefined) {
      const id = Number(r.id);
      const prev = byId.get(id) || { id };
      byId.set(id, { ...prev, ...r });
    }
  }
  return [...byId.values()].sort((a, b) => Number(a.id) - Number(b.id));
}

function findJobIndex(jobs, type) {
  return jobs.findIndex((j) => j && j.type === type);
}

const args = parseArgs(process.argv);
if (!args.base || !args.profile || !args.restBase || !args.output) {
  console.error(
    "Usage: node scripts/build-profiled-automation.js --base <automation.yaml> --profile <target.yaml> --rest-base <base-rest-api.yaml> --output <out.yaml>"
  );
  process.exit(1);
}

const automation = loadYaml(path.resolve(args.base));
const rest = loadYaml(path.resolve(args.restBase));
const profile = loadYaml(path.resolve(args.profile));

if (!automation.jobs || !Array.isArray(automation.jobs)) {
  console.error("Base automation must have a top-level jobs array.");
  process.exit(1);
}

const jobs = automation.jobs.filter(Boolean);

const passiveCfg = rest.passiveScanConfig;
if (passiveCfg && passiveCfg.type === "passiveScan-config") {
  const idx = findJobIndex(jobs, "passiveScan-wait");
  const insertAt = idx >= 0 ? idx : jobs.length;
  jobs.splice(insertAt, 0, { ...passiveCfg });
}

if (profile.overrides?.skipOpenApi === true) {
  for (let i = jobs.length - 1; i >= 0; i -= 1) {
    if (jobs[i].type === "openapi") jobs.splice(i, 1);
  }
}

const spiderIdx = findJobIndex(jobs, "spider");
if (spiderIdx >= 0 && profile.overrides?.spider) {
  jobs[spiderIdx].parameters = {
    ...jobs[spiderIdx].parameters,
    ...profile.overrides.spider,
  };
}

const activeIdx = findJobIndex(jobs, "activeScan");
if (activeIdx >= 0) {
  const pol = rest.activeScanPolicy?.policyDefinition;
  if (pol) {
    const mergedRules = deepMergePolicyRules(pol.rules, profile.overrides?.policyOverrides);
    jobs[activeIdx].policyDefinition = {
      ...pol,
      rules: mergedRules,
    };
  }
  if (profile.overrides?.activeScan) {
    jobs[activeIdx].parameters = {
      ...jobs[activeIdx].parameters,
      ...profile.overrides.activeScan,
    };
  }
}

const outDoc = { ...automation, jobs };
fs.mkdirSync(path.dirname(path.resolve(args.output)), { recursive: true });
fs.writeFileSync(path.resolve(args.output), YAML.stringify(outDoc, { lineWidth: 120 }), "utf8");
console.error("Wrote profiled automation:", path.resolve(args.output));
