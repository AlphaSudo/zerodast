const fs = require("fs");

const [rawSpecPath, sanitizedSpecPath, requestsPath, scannerBaseRoot, apiBasePath] =
  process.argv.slice(2);

if (!rawSpecPath || !sanitizedSpecPath || !requestsPath || !scannerBaseRoot || !apiBasePath) {
  console.error(
    "Usage: node prepare-openapi.js <rawSpec> <sanitizedSpec> <requestsJson> <scannerBaseRoot> <apiBasePath>"
  );
  process.exit(1);
}

const raw = JSON.parse(fs.readFileSync(rawSpecPath, "utf8"));

raw.openapi = "3.0.3";
delete raw.jsonSchemaDialect;
if (raw.info && raw.info.license) {
  delete raw.info.license.identifier;
  delete raw.info.license.extensions;
}
raw.servers = [{ url: apiBasePath, description: "Benchmark network target" }];

fs.writeFileSync(sanitizedSpecPath, JSON.stringify(raw));

const base = `${scannerBaseRoot}${apiBasePath}`;
const requests = [
  { url: `${base}/login/test-token`, method: "POST" },
  { url: `${base}/users/me`, method: "GET" },
  { url: `${base}/users/?skip=0&limit=10`, method: "GET" },
  { url: `${base}/users/?skip=10&limit=5`, method: "GET" },
  { url: `${base}/items/?skip=0&limit=10`, method: "GET" },
];

fs.writeFileSync(requestsPath, JSON.stringify(requests, null, 2));
