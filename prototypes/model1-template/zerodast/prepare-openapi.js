#!/usr/bin/env node
const fs = require('fs');

const [configPath, mode, rawSpecPath, outSpecPath, outRequestsPath] = process.argv.slice(2);
if (!configPath || !mode || !rawSpecPath || !outSpecPath || !outRequestsPath) {
  console.error('Usage: prepare-openapi.js <configPath> <mode> <rawSpec> <outSpec> <outRequests>');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const modeConfig = config.scan?.mode?.[mode];
if (!modeConfig) {
  console.error(`Unknown mode: ${mode}`);
  process.exit(1);
}

const port = Number(config.target?.port || 80);
const runtimeMode = config.target?.runtimeMode || 'artifact';
const host = runtimeMode === 'compose'
  ? (config.target?.compose?.appHost || 'zerodast-target')
  : 'zerodast-target';
const scannerBaseRoot = `http://${host}:${port}`;
const scannerBasePath = config.target?.basePath || '';
const scannerBaseUrl = `${scannerBaseRoot}${scannerBasePath}`;
let rawSpec = {};
const rawContent = fs.readFileSync(rawSpecPath, 'utf8').trim();
if (rawContent) {
  try { rawSpec = JSON.parse(rawContent); } catch { rawSpec = {}; }
}

if (rawSpec.info && rawSpec.info.license && typeof rawSpec.info.license === 'object') {
  delete rawSpec.info.license.extensions;
}

if (rawSpec.openapi || rawSpec.swagger || rawSpec.paths) {
  rawSpec.openapi = rawSpec.openapi || '3.0.3';
  rawSpec.servers = [{ url: scannerBasePath, description: 'ZeroDAST model-1 target' }];
}

const sampleValues = {
  ownerId: '1',
  petId: '1',
  vetId: '1',
  specialtyId: '1',
  petTypeId: '1',
  visitId: '1'
};

const requestUrls = new Set();
for (const [path, operations] of Object.entries(rawSpec.paths || {})) {
  if (!operations.get) continue;
  let resolvedPath = path;
  for (const match of path.matchAll(/\{([^}]+)\}/g)) {
    const paramName = match[1];
    resolvedPath = resolvedPath.replace(`{${paramName}}`, sampleValues[paramName] || '1');
  }
  requestUrls.add(`${scannerBaseRoot}${scannerBasePath}${resolvedPath}`);
}

for (const seed of config.scan?.requestSeeds || []) {
  requestUrls.add(`${scannerBaseRoot}${seed}`);
}

fs.writeFileSync(outSpecPath, JSON.stringify(rawSpec.paths ? rawSpec : { openapi: '3.0.3', info: { title: 'empty', version: '0' }, paths: {} }));
fs.writeFileSync(outRequestsPath, JSON.stringify(Array.from(requestUrls).sort(), null, 2));

const apiSignalPathPrefix = config.target?.apiSignalPathPrefix || `${scannerBasePath}/api/`;
const scanConfig = config.scan || {};
const spiderPath = modeConfig.spiderPath || scanConfig.spiderPath || `${scannerBasePath}/swagger-ui/index.html`;
const output = {
  target: config.target,
  zapVersion: scanConfig?.zapVersion,
  helperImage: scanConfig?.helperImage,
  mode,
  modeConfig,
  reporting: config.reporting || {},
  scannerBaseRoot,
  scannerBasePath,
  scannerBaseUrl,
  spiderTargetUrl: `${scannerBaseRoot}${spiderPath}`,
  apiSignalPrefix: `${scannerBaseRoot}${apiSignalPathPrefix}`,
  requestSeeds: scanConfig?.requestSeeds || []
};

process.stdout.write(JSON.stringify(output, null, 2));
