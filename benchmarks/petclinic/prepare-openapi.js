#!/usr/bin/env node
const fs = require('fs');

const [rawSpecPath, outSpecPath, outRequestsPath, scannerBaseRoot, scannerBasePath] = process.argv.slice(2);
if (!rawSpecPath || !outSpecPath || !outRequestsPath || !scannerBaseRoot || !scannerBasePath) {
  console.error('Usage: prepare-openapi.js <rawSpec> <outSpec> <outRequests> <scannerBaseRoot> <scannerBasePath>');
  process.exit(1);
}

const spec = JSON.parse(fs.readFileSync(rawSpecPath, 'utf8'));
if (spec.info && spec.info.license && typeof spec.info.license === 'object') {
  delete spec.info.license.extensions;
}
spec.openapi = '3.0.3';
spec.servers = [{ url: scannerBasePath, description: 'Petclinic benchmark network target' }];

const sampleValues = {
  ownerId: '1',
  petId: '1',
  vetId: '1',
  specialtyId: '1',
  petTypeId: '1',
  visitId: '1',
};

const requestUrls = new Set();
for (const [path, operations] of Object.entries(spec.paths || {})) {
  if (!operations.get) continue;
  let resolvedPath = path;
  for (const match of path.matchAll(/\{([^}]+)\}/g)) {
    const paramName = match[1];
    resolvedPath = resolvedPath.replace(`{${paramName}}`, sampleValues[paramName] || '1');
  }
  requestUrls.add(`${scannerBaseRoot}${scannerBasePath}${resolvedPath}`);
}
requestUrls.add(`${scannerBaseRoot}${scannerBasePath}/api/owners?lastName=Davis`);

fs.writeFileSync(outSpecPath, JSON.stringify(spec));
fs.writeFileSync(outRequestsPath, JSON.stringify(Array.from(requestUrls).sort(), null, 2));
