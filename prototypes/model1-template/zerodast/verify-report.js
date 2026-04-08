#!/usr/bin/env node
const fs = require('fs');

const [reportPath, metricsPath, preparedConfigPath, logPath, requestsPath] = process.argv.slice(2);
if (!reportPath || !metricsPath || !preparedConfigPath) {
  console.error('Usage: verify-report.js <reportPath> <metricsPath> <preparedConfigPath> [logPath] [requestsPath]');
  process.exit(1);
}
if (!fs.existsSync(reportPath)) {
  console.error(`Missing report file: ${reportPath}`);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const metrics = JSON.parse(fs.readFileSync(metricsPath, 'utf8'));
const prepared = JSON.parse(fs.readFileSync(preparedConfigPath, 'utf8'));
const riskCounts = { critical: 0, high: 0, medium: 0, low: 0, informational: 0 };
const apiUris = new Set();
const apiPrefix = prepared.apiSignalPrefix || `${prepared.scannerBaseUrl}/api/`;

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
      if (uri.startsWith(apiPrefix)) apiUris.add(uri);
    }
  }
}

const configuredSeedUrls = new Set();
if (requestsPath && fs.existsSync(requestsPath)) {
  for (const url of JSON.parse(fs.readFileSync(requestsPath, 'utf8'))) {
    configuredSeedUrls.add(String(url));
  }
}

const observedRequestorUrls = new Set();
let spiderFoundCount = null;
let openApiAddedCount = null;
if (logPath && fs.existsSync(logPath)) {
  const log = fs.readFileSync(logPath, 'utf8');
  for (const match of log.matchAll(/^Job requestor requesting URL (.+)$/gm)) {
    observedRequestorUrls.add(match[1].trim());
  }
  const spiderMatch = log.match(/Job spider found (\d+) URLs/);
  if (spiderMatch) spiderFoundCount = Number(spiderMatch[1]);
  const openApiMatch = log.match(/Job openapi added (\d+) URLs/);
  if (openApiMatch) openApiAddedCount = Number(openApiMatch[1]);
}

const observedApiRequestorUrls = new Set(
  Array.from(observedRequestorUrls).filter((uri) => uri.startsWith(apiPrefix))
);
const configuredSeedApiUrls = new Set(
  Array.from(configuredSeedUrls).filter((uri) => uri.startsWith(apiPrefix))
);
const missingSeedUrls = Array.from(configuredSeedUrls).filter((uri) => !observedRequestorUrls.has(uri));

const lines = [
  '# ZeroDAST Model 1 Summary',
  '',
  `- Mode: ${prepared.mode}`,
  `- Spec mode: ${metrics.specMode || 'unknown'}`,
  `- ZAP image: ${metrics.zapImage || 'unknown'}`,
  `- Cold run duration: ${metrics.coldRunSeconds ?? 'unknown'}s`,
  `- Seeded request count: ${metrics.seededRequestCount ?? 'unknown'}`,
  `- API alert URI count: ${apiUris.size}`,
  `- Observed requestor URL count: ${observedRequestorUrls.size}`,
  `- Observed API requestor URL count: ${observedApiRequestorUrls.size}`,
  `- Configured API seed URL count: ${configuredSeedApiUrls.size}`,
  `- OpenAPI imported URL count: ${openApiAddedCount ?? 'unknown'}`,
  `- Spider discovered URL count: ${spiderFoundCount ?? 'unknown'}`,
  '',
  '| Risk | Count |',
  '| --- | ---: |',
  `| Critical | ${riskCounts.critical} |`,
  `| High | ${riskCounts.high} |`,
  `| Medium | ${riskCounts.medium} |`,
  `| Low | ${riskCounts.low} |`,
  `| Informational | ${riskCounts.informational} |`
];

if (configuredSeedUrls.size > 0) {
  lines.push('', '## Route Exercise', '');
  lines.push(`- Configured seed URLs observed by requestor: ${configuredSeedUrls.size - missingSeedUrls.length}/${configuredSeedUrls.size}`);
  if (missingSeedUrls.length > 0) {
    lines.push('', '### Seed URLs not observed in requestor logs', '');
    for (const uri of missingSeedUrls.sort()) lines.push(`- ${uri}`);
  }
}

if (observedApiRequestorUrls.size > 0) {
  lines.push('', '## Observed API Requestor URLs', '');
  for (const uri of Array.from(observedApiRequestorUrls).sort()) lines.push(`- ${uri}`);
}

if (apiUris.size > 0) {
  lines.push('', '## API URIs with Alert Instances', '');
  for (const uri of Array.from(apiUris).sort()) lines.push(`- ${uri}`);
}

const body = lines.join('\n');
process.stdout.write(body);
process.exit(apiUris.size >= 1 ? 0 : 1);
