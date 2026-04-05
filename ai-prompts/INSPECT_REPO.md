# INSPECT_REPO Prompt

You are analyzing a repository so ZeroDAST can adapt its DAST pipeline safely.
Your goal is to produce a compact, structured profile of the target application and the inputs needed to generate scan configuration, auth bootstrapping, and seed data.

## What to inspect
1. Tech stack
- Read manifest/build files first.
- Identify the primary runtime, framework, package manager, and test tooling.
- Note whether the app is monorepo-rooted or nested in a subdirectory.

2. API surface
- Find route/controller definitions.
- Extract representative endpoints, HTTP methods, route prefixes, and health endpoints.
- Prefer real code definitions over generated docs.
- If route extraction is ambiguous, say so clearly.

3. Authentication model
- Determine whether the app uses JWT, session cookies, API keys, OAuth2, or mixed auth.
- Identify login endpoints, required headers, cookies, CSRF tokens, and auth bootstrap prerequisites.
- Call out whether machine-driven login appears feasible.

4. Data model and seeding
- Find migrations, schema files, ORM models, fixtures, or SQL seed files.
- Identify core relational entities needed for meaningful authenticated scans.
- Highlight whether safe additive overlay data seems possible.

5. DAST execution prerequisites
- Identify Dockerfiles, compose files, env vars, DB dependencies, healthcheck endpoints, API docs, and startup order.
- Look for OpenAPI/Swagger docs and whether raw JSON is available.
- Identify anything that would block isolated scanning, such as external SaaS hard dependencies.

## Output requirements
Return YAML only.
Use this shape:

```yaml
repo_profile:
  app_name: ""
  working_directory: ""
  runtime: ""
  framework: ""
  package_manager: ""
  api_style: ""
  health_endpoint: ""
  openapi:
    available: true
    json_path: ""
    ui_path: ""
  auth:
    mode: ""
    login_endpoint: ""
    bootstrap_feasible: true
    required_headers: []
    required_cookies: []
    notes: []
  data:
    primary_store: ""
    schema_sources: []
    seed_sources: []
    overlay_feasible: true
    notes: []
  routes:
    route_files: []
    representative_endpoints:
      - method: "GET"
        path: "/health"
        auth: "public"
  dast_inputs:
    docker_assets: []
    startup_requirements: []
    environment_variables: []
    blockers: []
  confidence_notes: []
```

## Rules
- Do not invent files or endpoints.
- Prefer concise facts over long explanations.
- If multiple apps exist, identify the most likely scan target and mention alternatives in `confidence_notes`.
- If a detail is inferred rather than explicit, label it as an inference.
