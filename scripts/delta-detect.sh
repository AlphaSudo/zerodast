#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${BASE_REF:-origin/main}"
HEAD_REF="${HEAD_REF:-HEAD}"
CHANGED_FILES=$(git diff --name-only "${BASE_REF}...${HEAD_REF}")
ROUTE_CHANGES=""
CORE_CHANGED=false

extract_routes_from_file() {
  local file="$1"
  grep -oE "(router|app)\.(get|post|put|delete|patch)\s*\(['\"][^'\"]+['\"]" "$file" \
    | grep -oE "['\"][^'\"]+['\"]" \
    | tr -d "'\"" || true
}

for file in $CHANGED_FILES; do
  case "$file" in
    */routes/*.js|*/routes/*.ts|*/controllers/*.js|*/controllers/*.py)
      endpoints=$(extract_routes_from_file "$file")
      ROUTE_CHANGES="$ROUTE_CHANGES $endpoints"
      ;;
    */middleware/*|*/db.*|*/index.js|*/app.js|Dockerfile|docker-compose*)
      CORE_CHANGED=true
      ;;
  esac
done

if [[ "$CORE_CHANGED" == true ]] || [[ -z "$(echo "$ROUTE_CHANGES" | tr -d '[:space:]')" ]]; then
  echo "FULL"
  exit 0
fi

echo "$ROUTE_CHANGES" | tr ' ' '\n' | sort -u | grep -v '^$'
