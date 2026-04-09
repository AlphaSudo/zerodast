#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_ADAPTER_SCRIPT="$ROOT_DIR/scripts/auth-adapters/form-cookie-login.sh"

AUTH_ADAPTER_SCRIPT="$AUTH_ADAPTER_SCRIPT" bash "$ROOT_DIR/scripts/run-auth-adapter-smoke.sh"
