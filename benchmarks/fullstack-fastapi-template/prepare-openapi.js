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

function sampleScalar(schema = {}) {
  if (schema.example !== undefined) {
    return String(schema.example);
  }
  if (schema.default !== undefined) {
    return String(schema.default);
  }
  if (Array.isArray(schema.enum) && schema.enum.length > 0) {
    return String(schema.enum[0]);
  }
  switch (schema.type) {
    case "integer":
    case "number":
      return "1";
    case "boolean":
      return "true";
    default:
      return "sample";
  }
}

function resolveParameterValue(parameter = {}) {
  if (parameter.example !== undefined) {
    return String(parameter.example);
  }
  if (/id$/i.test(parameter.name || "")) {
    return "1";
  }
  return sampleScalar(parameter.schema || {});
}

function buildRequestUrl(pathTemplate, operation = {}) {
  let path = pathTemplate;
  const query = new URLSearchParams();

  const parameters = [
    ...(raw.paths?.[pathTemplate]?.parameters || []),
    ...(operation.parameters || []),
  ];

  for (const parameter of parameters) {
    const value = resolveParameterValue(parameter);
    if (parameter.in === "path") {
      path = path.replace(`{${parameter.name}}`, encodeURIComponent(value));
      continue;
    }
    if (parameter.in === "query") {
      query.set(parameter.name, value);
    }
  }

  const queryString = query.toString();
  const normalizedPath = path.startsWith(apiBasePath) ? path : `${apiBasePath}${path}`;
  return `${scannerBaseRoot}${normalizedPath}${queryString ? `?${queryString}` : ""}`;
}

const generatedRequests = [];
const requestKeys = new Set(requests.map((request) => `${request.method} ${request.url}`));

for (const [pathTemplate, pathItem] of Object.entries(raw.paths || {})) {
  for (const [methodName, operation] of Object.entries(pathItem || {})) {
    const method = methodName.toUpperCase();
    if (!["GET", "HEAD"].includes(method)) {
      continue;
    }
    const url = buildRequestUrl(pathTemplate, operation);
    const key = `${method} ${url}`;
    if (requestKeys.has(key)) {
      continue;
    }
    requestKeys.add(key);
    generatedRequests.push({ url, method });
  }
}

const boundedGeneratedRequests = generatedRequests.slice(0, 12);
const combinedRequests = [...requests, ...boundedGeneratedRequests];

fs.writeFileSync(requestsPath, JSON.stringify(combinedRequests, null, 2));
