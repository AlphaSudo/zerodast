#!/usr/bin/env node
const fs = require('fs');

const [summaryPath] = process.argv.slice(2);
if (!summaryPath) {
  console.error('Usage: verify-report.js <summaryPath>');
  process.exit(1);
}
if (!fs.existsSync(summaryPath)) {
  console.error(`Missing summary file: ${summaryPath}`);
  process.exit(1);
}
const body = fs.readFileSync(summaryPath, 'utf8');
if (!body.includes('prototype runner executed')) {
  console.error('Summary does not contain the expected prototype marker.');
  process.exit(1);
}
process.stdout.write(body);
