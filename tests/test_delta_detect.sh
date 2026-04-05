#!/usr/bin/env bash
set -euo pipefail

workdir=$(mktemp -d)
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

repo="$workdir/repo"
mkdir -p "$repo/demo-app/src/routes" "$repo/demo-app/src/middleware"
cd "$repo"

git init -q
git config user.email "test@example.com"
git config user.name "Test User"

cat <<'EOF' > demo-app/src/routes/users.js
const router = {};
router.get('/api/users', handler);
EOF

git add .
git commit -q -m "base"
git branch -M main

run_delta() {
  BASE_REF=main HEAD_REF=HEAD "C:/Program Files/Git/bin/bash.exe" 'C:/Java Developer/DAST/scripts/delta-detect.sh'
}

# Scenario 1: route additions are extracted.
git checkout -q -b feature-routes
cat <<'EOF' > demo-app/src/routes/users.js
const router = {};
router.get('/api/users', handler);
app.post('/api/auth/login', handler);
EOF
git add demo-app/src/routes/users.js
git commit -q -m "route changes"
result=$(run_delta)
echo "$result" | grep -qx '/api/auth/login'
echo "$result" | grep -qx '/api/users'

git checkout -q main

# Scenario 2: middleware change forces FULL.
git checkout -q -b feature-middleware
cat <<'EOF' > demo-app/src/middleware/auth.js
module.exports = function auth(req, res, next) { next(); };
EOF
git add demo-app/src/middleware/auth.js
git commit -q -m "middleware change"
result=$(run_delta)
[[ "$result" == "FULL" ]]

git checkout -q main

# Scenario 3: Dockerfile change forces FULL.
git checkout -q -b feature-docker
cat <<'EOF' > Dockerfile
FROM node:20-alpine
EOF
git add Dockerfile
git commit -q -m "docker change"
result=$(run_delta)
[[ "$result" == "FULL" ]]

git checkout -q main

# Scenario 4: non-route js change falls back to FULL.
git checkout -q -b feature-note
cat <<'EOF' > note.js
console.log('not a route file');
EOF
git add note.js
git commit -q -m "note change"
result=$(run_delta)
[[ "$result" == "FULL" ]]

echo "delta-detect tests passed"
