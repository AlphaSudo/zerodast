const fs = require("fs");

const [reportPath, metricsPath, logPath] = process.argv.slice(2);

if (!reportPath || !metricsPath) {
  console.error("Usage: node verify-t4.js <reportPath> <metricsPath> [logPath]");
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const metrics = JSON.parse(fs.readFileSync(metricsPath, "utf8"));
const logText = logPath && fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";
const apiInventoryPath = metrics.apiInventoryJsonPath || "";
const apiInventory =
  apiInventoryPath && fs.existsSync(apiInventoryPath)
    ? JSON.parse(fs.readFileSync(apiInventoryPath, "utf8"))
    : null;

const alerts = [];
const apiUris = new Set();
const adminRouteUrl = metrics.adminRouteUrl || "";
const adminRouteEvidence = new Set();

for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    alerts.push({
      name: alert.alert,
      riskCode: Number(alert.riskcode),
      count: Number(alert.count),
    });
    for (const instance of alert.instances || []) {
      if ((instance.uri || "").includes("/api/v1/")) {
        apiUris.add(instance.uri);
      }
      if (adminRouteUrl && (instance.uri || "").includes(adminRouteUrl)) {
        adminRouteEvidence.add(instance.uri);
      }
    }
  }
}

if (adminRouteUrl) {
  for (const line of logText.split(/\r?\n/)) {
    if (line.includes("Job requestor requesting URL") && line.includes(adminRouteUrl)) {
      adminRouteEvidence.add(line.trim());
    }
  }
}

const grouped = [...new Map(alerts.map((item) => [item.name, item])).values()].sort(
  (a, b) => b.riskCode - a.riskCode || a.name.localeCompare(b.name)
);

const lines = [
  "# Fullstack FastAPI T4 Verification",
  "",
  `- Spec mode: ${metrics.specMode}`,
  `- ZAP image: ${metrics.zapImage}`,
  `- ZAP exit code: ${metrics.zapExitCode}`,
  `- Cold run seconds: ${metrics.coldRunSeconds}`,
  `- Auth bootstrap status: ${metrics.authBootstrapStatus}`,
  `- Protected route validation status: ${metrics.protectedValidationStatus}`,
  `- Admin route validation status: ${metrics.adminValidationStatus ?? "unknown"}`,
  `- Seeded request count: ${metrics.seededRequestCount}`,
  `- OpenAPI imported URL count: ${metrics.openApiImportedUrlCount}`,
  `- Spider discovered URL count: ${metrics.spiderDiscoveredUrlCount}`,
  `- API alert URI count: ${apiUris.size}`,
  `- Admin route exercised: ${adminRouteEvidence.size > 0 ? "yes" : "no"}`,
  "",
  "## Alerts",
  "",
];

for (const alert of grouped) {
  lines.push(`- ${alert.name} (riskCode=${alert.riskCode}, count=${alert.count})`);
}

if (apiInventory) {
  lines.push(
    "",
    "## API Inventory",
    "",
    `- OpenAPI route count: ${apiInventory.openApiRouteCount}`,
    `- OpenAPI operation count: ${apiInventory.openApiOperationCount}`,
    `- Requestor route count: ${apiInventory.requestorRouteCount}`,
    `- Observed OpenAPI routes: ${apiInventory.observedSpecRouteCount}`,
    `- Unobserved OpenAPI routes: ${apiInventory.unobservedSpecRouteCount}`
  );
}

if (apiUris.size > 0) {
  lines.push("", "## API URIs with Alert Instances", "");
  for (const uri of [...apiUris].sort()) {
    lines.push(`- ${uri}`);
  }
}

if (adminRouteEvidence.size > 0) {
  lines.push("", "## Admin Route Evidence", "");
  for (const entry of [...adminRouteEvidence].sort()) {
    lines.push(`- ${entry}`);
  }
}

if (apiInventory && Array.isArray(apiInventory.unobservedSpecRoutes) && apiInventory.unobservedSpecRoutes.length > 0) {
  lines.push("", "## Unobserved OpenAPI Routes", "");
  for (const route of apiInventory.unobservedSpecRoutes.slice(0, 12)) {
    lines.push(`- ${route}`);
  }
}

process.stdout.write(lines.join("\n") + "\n");
