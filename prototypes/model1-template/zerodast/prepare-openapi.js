#!/usr/bin/env node
const fs = require('fs');

const [configPath, mode] = process.argv.slice(2);
if (!configPath || !mode) {
  console.error('Usage: prepare-openapi.js <configPath> <mode>');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const modeConfig = config.scan?.mode?.[mode];
if (!modeConfig) {
  console.error(`Unknown mode: ${mode}`);
  process.exit(1);
}

const output = {
  target: config.target,
  zapVersion: config.scan?.zapVersion,
  mode,
  modeConfig,
  requestSeeds: config.scan?.requestSeeds || []
};

process.stdout.write(JSON.stringify(output, null, 2));
