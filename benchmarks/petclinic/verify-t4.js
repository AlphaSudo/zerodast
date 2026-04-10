#!/usr/bin/env node
const fs = require('fs');

const reportPath = process.argv[2];
const metricsPath = process.argv[3];
if (!reportPath) {
  console.error('Usage: verify-t4.js <reportPath> [metricsPath]');
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const metrics = metricsPath && fs.existsSync(metricsPath) ? JSON.parse(fs.readFileSync(metricsPath, 'utf8')) : {};
const apiInventoryPath = metrics.apiInventoryJsonPath || "";
const apiInventory =
  apiInventoryPath && fs.existsSync(apiInventoryPath)
    ? JSON.parse(fs.readFileSync(apiInventoryPath, 'utf8'))
    : null;
const inventoryCounts = apiInventory?.counts || null;
const riskCounts = { critical: 0, high: 0, medium: 0, low: 0, informational: 0 };
const apiUris = new Set();

for (const site of report.site || []) {
  for (const alert of site.alerts || []) {
    const code = Number(alert.riskcode ?? 0);
    if (code === 4) riskCounts.critical += 1;
    else if (code === 3) riskCounts.high += 1;
    else if (code === 2) riskCounts.medium += 1;
    else if (code === 1) riskCounts.low += 1;
    else riskCounts.informational += 1;

    for (const instance of alert.instances || []) {
      const uri = String(instance.uri || '');
      if (uri.includes('/petclinic/api/')) apiUris.add(uri);
    }
  }
}

const lines = [
  '# Petclinic T4 Verification',
  '',
  `- Spec mode: ${metrics.specMode || 'unknown'}`,
  `- ZAP image: ${metrics.zapImage || 'unknown'}`,
  `- Cold run duration: ${metrics.coldRunSeconds ?? 'unknown'}s`,
  `- Seeded request count: ${metrics.seededRequestCount ?? 'unknown'}`,
  `- API alert URI count: ${apiUris.size}`,
  '',
  '| Risk | Count |',
  '| --- | ---: |',
  `| Critical | ${riskCounts.critical} |`,
  `| High | ${riskCounts.high} |`,
  `| Medium | ${riskCounts.medium} |`,
  `| Low | ${riskCounts.low} |`,
  `| Informational | ${riskCounts.informational} |`,
];

if (apiInventory && inventoryCounts) {
  lines.push(
    '',
    '## API Inventory',
    '',
    `- OpenAPI route count: ${inventoryCounts.openApiRouteCount}`,
    `- OpenAPI operation count: ${inventoryCounts.openApiOperationCount}`,
    `- Observed OpenAPI routes: ${inventoryCounts.observedSpecRouteCount}`,
    `- Unobserved OpenAPI routes: ${inventoryCounts.unobservedSpecRouteCount}`,
    `- Undocumented observed routes: ${inventoryCounts.undocumentedObservedRouteCount}`,
    `- Code-hinted routes: ${inventoryCounts.hintedRouteCount}`,
    `- Code-hinted observed routes: ${inventoryCounts.hintedObservedRouteCount}`,
    `- Code-hinted unobserved routes: ${inventoryCounts.hintedUnobservedRouteCount}`,
    `- Code-hinted routes outside spec: ${inventoryCounts.hintedOnlyRouteCount}`
  );
}

if (apiUris.size > 0) {
  lines.push('', '## API URIs with Alert Instances', '');
  for (const uri of Array.from(apiUris).sort()) lines.push(`- ${uri}`);
}

if (apiInventory && Array.isArray(apiInventory.unobservedSpecRoutes) && apiInventory.unobservedSpecRoutes.length > 0) {
  lines.push('', '## Unobserved OpenAPI Routes', '');
  for (const route of apiInventory.unobservedSpecRoutes.slice(0, 12)) lines.push(`- ${route}`);
}

if (apiInventory && Array.isArray(apiInventory.hintedUnobservedRoutes) && apiInventory.hintedUnobservedRoutes.length > 0) {
  lines.push('', '## Code-Hinted Unobserved Routes', '');
  for (const route of apiInventory.hintedUnobservedRoutes.slice(0, 12)) lines.push(`- ${route}`);
}

console.log(lines.join('\n'));
process.exit(apiUris.size >= 1 ? 0 : 1);
