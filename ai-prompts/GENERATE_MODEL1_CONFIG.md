# GENERATE_MODEL1_CONFIG Prompt

You are generating a valid `zerodast/config.json` file for the ZeroDAST Model 1 in-repo prototype.
The output must be directly usable by `zerodast/run-scan.sh` without manual editing beyond credentials.

## Inputs
- The `INSPECT_REPO` YAML profile for the target repository
- Optional `ADAPT_AUTH` output if authentication was analyzed
- The target repository's Docker Compose file (if compose mode)

## Field Mapping

Map the `INSPECT_REPO` profile to `config.json` fields as follows:

| INSPECT_REPO field | config.json field |
| --- | --- |
| `app_name` | `name` (prefix with `zerodast-`) |
| `working_directory` | `target.workingDirectory` |
| `runtime` | Determines `target.runtimeMode` and `target.appImage` |
| `health_endpoint` | `target.healthPath` |
| `openapi.json_path` | `target.openApiPath` |
| `auth.mode` | `auth.adapter` (see adapter selection below) |
| `auth.login_endpoint` | `auth.loginPath` |
| `routes.representative_endpoints` | `scan.requestSeeds` (GET endpoints only) |
| `dast_inputs.docker_assets` | Determines compose commands |

## Runtime Mode Selection

- If the repo has a `docker-compose.yml` or `compose.yaml` → use `"runtimeMode": "compose"`
- If the repo builds a standalone JAR/binary → use `"runtimeMode": "artifact"`
- Compose mode is preferred when the app has service dependencies (DB, Redis, etc.)

## Adapter Selection

Map the detected auth mode to one of the four bundled adapters:

| Auth pattern | `auth.adapter` value | Key config fields |
| --- | --- | --- |
| JSON POST → JWT/token response | `json-token-login` | `emailField`, `passwordField`, `responseTokenField`, `headerPrefix: "Bearer "` |
| Form POST → Set-Cookie response | `form-cookie-login` | `emailField`, `passwordField`, `contentType: "application/x-www-form-urlencoded"` |
| JSON POST → session ID response | `json-session-login` | `emailField`, `passwordField`, `responseTokenField` (session field), `headerPrefix: "Session "` |
| Form-urlencoded POST → token response | `form-urlencoded-token-login` | `emailField` (often `username`), `passwordField`, `responseTokenField` (often `access_token`), `contentType: "application/x-www-form-urlencoded"` |
| No auth / public API | Leave `auth.adapter` as `""` | |

## Compose Mode Fields

When using compose mode, you must determine:
- `target.compose.upCommand`: the command to start the stack (e.g., `docker compose up -d`)
- `target.compose.downCommand`: the command to tear it down (e.g., `docker compose down -v --remove-orphans`)
- `target.compose.networkName`: the Docker network name (usually `<directory>_default` or check compose file)
- `target.compose.appHost`: the service name of the main app container in the compose network

## Required Output

Return a single JSON code block containing the complete `config.json`. Use this exact structure:

```json
{
  "name": "zerodast-<app-name>",
  "target": {
    "runtimeMode": "compose",
    "startCommand": "",
    "buildCommand": "",
    "artifactPattern": "",
    "workingDirectory": ".",
    "port": 8080,
    "basePath": "",
    "apiSignalPathPrefix": "/api/",
    "healthPath": "/health",
    "openApiPath": "/api/docs",
    "appImage": "node:20-alpine",
    "compose": {
      "upCommand": "docker compose up -d",
      "downCommand": "docker compose down -v --remove-orphans",
      "networkName": "",
      "appHost": ""
    }
  },
  "auth": {
    "adapter": "",
    "loginPath": "",
    "contentType": "application/json",
    "emailField": "email",
    "passwordField": "password",
    "responseTokenField": "token",
    "headerName": "Authorization",
    "headerPrefix": "Bearer ",
    "user": {
      "email": "",
      "password": ""
    },
    "admin": {
      "email": "",
      "password": ""
    },
    "protectedRoute": {
      "path": "",
      "expectedStatus": 200
    },
    "adminRoute": {
      "path": "",
      "expectedStatus": 200
    }
  },
  "scan": {
    "zapVersion": "2.17.0",
    "helperImage": "node:20-alpine",
    "spiderPath": "",
    "mode": {
      "pr": {
        "maxDurationMinutes": 5,
        "enableSpider": true,
        "spiderMinutes": 1,
        "spiderMaxDepth": 5,
        "spiderMaxChildren": 50,
        "passiveWaitMinutes": 2,
        "threadPerHost": 4,
        "defaultStrength": "medium",
        "defaultThreshold": "low"
      },
      "nightly": {
        "maxDurationMinutes": 15,
        "enableSpider": true,
        "spiderMinutes": 2,
        "spiderMaxDepth": 5,
        "spiderMaxChildren": 50,
        "passiveWaitMinutes": 2,
        "threadPerHost": 4,
        "defaultStrength": "medium",
        "defaultThreshold": "low"
      }
    },
    "requestSeeds": []
  },
  "reporting": {
    "successMode": "route_exercise",
    "minApiAlertUris": 1,
    "minObservedApiRequestorUrls": 1,
    "minSeedObservationRatio": 0.5
  }
}
```

## Rules
- Every field must be populated or left as the correct empty default.
- `requestSeeds` should contain 3-8 representative GET endpoints from the INSPECT_REPO routes.
- Prefix seed paths with the `basePath` if one exists.
- Use `route_exercise` success mode for compose targets (they may not trigger ZAP alerts on first scan).
- Use `api_alerts` success mode only for targets known to have exploitable vulnerabilities.
- Leave user/admin email and password empty with a comment indicating they must be set by the operator.
- If auth is not needed, leave the entire `auth` section with empty strings.
- Do not invent endpoints or paths not found in the inspection profile.
- If the compose network name cannot be determined from the compose file, leave it empty with a note.
