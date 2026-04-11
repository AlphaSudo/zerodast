const fs = require("fs");

const metricsPath = process.argv[2];
const outJsonPath = process.argv[3];
const outMdPath = process.argv[4];

if (!metricsPath || !outJsonPath || !outMdPath) {
  console.error(
    "Usage: node scripts/build-operational-reliability.js <metricsPath> <outJsonPath> <outMdPath>"
  );
  process.exit(1);
}

const metrics = JSON.parse(fs.readFileSync(metricsPath, "utf8"));

function asNumber(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function asBool(value) {
  return value === true;
}

const issues = [];
const warnings = [];

if (!asBool(metrics.dbReady)) {
  issues.push("Database readiness never completed.");
}

if (!asBool(metrics.appReady)) {
  issues.push("Application readiness never completed.");
}

if (asBool(metrics.authValidationAttempted) && !asBool(metrics.authValidationPassed)) {
  issues.push("Protected-route auth validation did not complete successfully.");
}

if (asBool(metrics.adminValidationAttempted) && !asBool(metrics.adminValidationPassed)) {
  issues.push("Admin-route validation did not complete successfully.");
}

if (asBool(metrics.zapRunRequested) && !asBool(metrics.zapRunCompleted)) {
  issues.push("ZAP execution did not complete.");
}

if (asBool(metrics.zapRunRequested) && !asBool(metrics.reportProduced)) {
  issues.push("ZAP report was not produced.");
}

if (asBool(metrics.zapRunRequested) && !asBool(metrics.resultStateProduced)) {
  issues.push("Result-state artifact was not produced.");
}

if (asBool(metrics.zapRunRequested) && !asBool(metrics.remediationGuideProduced)) {
  issues.push("Remediation guide was not produced.");
}

if (asBool(metrics.postScanAttempted) && !asBool(metrics.postScanCompleted)) {
  issues.push("Post-scan verification did not complete successfully.");
}

if (asBool(metrics.authzAttempted) && !asBool(metrics.authzCompleted)) {
  issues.push("AuthZ network checks did not complete successfully.");
}

const dbReadySeconds = asNumber(metrics.dbReadySeconds);
const appReadySeconds = asNumber(metrics.appReadySeconds);
const totalRuntimeSeconds = asNumber(metrics.totalRuntimeSeconds);

if (dbReadySeconds !== null && dbReadySeconds > 5) {
  warnings.push(`Database readiness was slower than expected (${dbReadySeconds}s).`);
}

if (appReadySeconds !== null && appReadySeconds > 10) {
  warnings.push(`Application readiness was slower than expected (${appReadySeconds}s).`);
}

if (totalRuntimeSeconds !== null && totalRuntimeSeconds > 360) {
  warnings.push(`Total runtime exceeded the preferred envelope (${totalRuntimeSeconds}s).`);
}

const state = issues.length > 0 ? "failed" : warnings.length > 0 ? "degraded" : "healthy";

const summary =
  state === "healthy"
    ? "Core scan runtime completed cleanly."
    : state === "degraded"
      ? "Core scan runtime completed, but operator attention is recommended."
      : "Core scan runtime did not complete cleanly and needs operator attention.";

const result = {
  state,
  summary,
  timings: {
    totalRuntimeSeconds,
    dbReadySeconds,
    appReadySeconds,
  },
  checks: {
    dbReady: asBool(metrics.dbReady),
    appReady: asBool(metrics.appReady),
    authValidationAttempted: asBool(metrics.authValidationAttempted),
    authValidationPassed: asBool(metrics.authValidationPassed),
    adminValidationAttempted: asBool(metrics.adminValidationAttempted),
    adminValidationPassed: asBool(metrics.adminValidationPassed),
    zapRunRequested: asBool(metrics.zapRunRequested),
    zapRunCompleted: asBool(metrics.zapRunCompleted),
    reportProduced: asBool(metrics.reportProduced),
    apiInventoryProduced: asBool(metrics.apiInventoryProduced),
    resultStateProduced: asBool(metrics.resultStateProduced),
    remediationGuideProduced: asBool(metrics.remediationGuideProduced),
    postScanAttempted: asBool(metrics.postScanAttempted),
    postScanCompleted: asBool(metrics.postScanCompleted),
    authzAttempted: asBool(metrics.authzAttempted),
    authzCompleted: asBool(metrics.authzCompleted),
  },
  issues,
  warnings,
};

const lines = [
  "# Operational Reliability",
  "",
  `- State: ${result.state}`,
  `- Summary: ${result.summary}`,
  `- Total runtime seconds: ${result.timings.totalRuntimeSeconds ?? "N/A"}`,
  `- Database ready seconds: ${result.timings.dbReadySeconds ?? "N/A"}`,
  `- Application ready seconds: ${result.timings.appReadySeconds ?? "N/A"}`,
  "",
  "## Runtime Checks",
  "",
  `- Database ready: ${result.checks.dbReady ? "yes" : "no"}`,
  `- Application ready: ${result.checks.appReady ? "yes" : "no"}`,
  `- Protected-route validation passed: ${
    result.checks.authValidationAttempted ? (result.checks.authValidationPassed ? "yes" : "no") : "not attempted"
  }`,
  `- Admin-route validation passed: ${
    result.checks.adminValidationAttempted ? (result.checks.adminValidationPassed ? "yes" : "no") : "not attempted"
  }`,
  `- ZAP run completed: ${result.checks.zapRunRequested ? (result.checks.zapRunCompleted ? "yes" : "no") : "not requested"}`,
  `- Report produced: ${result.checks.reportProduced ? "yes" : "no"}`,
  `- API inventory produced: ${result.checks.apiInventoryProduced ? "yes" : "no"}`,
  `- Result state produced: ${result.checks.resultStateProduced ? "yes" : "no"}`,
  `- Remediation guide produced: ${result.checks.remediationGuideProduced ? "yes" : "no"}`,
  `- AuthZ checks completed: ${
    result.checks.authzAttempted ? (result.checks.authzCompleted ? "yes" : "no") : "not attempted"
  }`,
  `- Post-scan verification completed: ${
    result.checks.postScanAttempted ? (result.checks.postScanCompleted ? "yes" : "no") : "not attempted"
  }`,
];

if (result.issues.length > 0) {
  lines.push("", "## Issues", "", ...result.issues.map((issue) => `- ${issue}`));
}

if (result.warnings.length > 0) {
  lines.push("", "## Warnings", "", ...result.warnings.map((warning) => `- ${warning}`));
}

fs.writeFileSync(outJsonPath, JSON.stringify(result, null, 2));
fs.writeFileSync(outMdPath, `${lines.join("\n")}\n`);
