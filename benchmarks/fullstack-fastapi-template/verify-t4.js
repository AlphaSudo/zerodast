const fs = require("fs");

const [reportPath, metricsPath] = process.argv.slice(2);

if (!reportPath || !metricsPath) {
  console.error("Usage: node verify-t4.js <reportPath> <metricsPath>");
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const metrics = JSON.parse(fs.readFileSync(metricsPath, "utf8"));

const alerts = [];
const apiUris = new Set();

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
  `- Seeded request count: ${metrics.seededRequestCount}`,
  `- OpenAPI imported URL count: ${metrics.openApiImportedUrlCount}`,
  `- Spider discovered URL count: ${metrics.spiderDiscoveredUrlCount}`,
  `- API alert URI count: ${apiUris.size}`,
  "",
  "## Alerts",
  "",
];

for (const alert of grouped) {
  lines.push(`- ${alert.name} (riskCode=${alert.riskCode}, count=${alert.count})`);
}

if (apiUris.size > 0) {
  lines.push("", "## API URIs with Alert Instances", "");
  for (const uri of [...apiUris].sort()) {
    lines.push(`- ${uri}`);
  }
}

process.stdout.write(lines.join("\n") + "\n");
