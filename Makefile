SHELL := C:/Program Files/PowerShell/7/pwsh.exe
.SHELLFLAGS := -NoProfile -Command

COMPOSE = docker compose
PYTHON = C:\\Users\\CM\\AppData\\Local\\Programs\\Python\\Python311\\python.exe
GIT_BASH = C:\\Program Files\\Git\\bin\\bash.exe
NPM = C:\\Users\\CM\\AppData\\Roaming\\fnm\\node-versions\\v22.15.0\\installation\\npm.cmd

.PHONY: build up seed dast validate test authz clean lint app-test

build:
	$(COMPOSE) build app

up:
	$(COMPOSE) up -d db app

seed:
	Get-Content -Raw 'db/seed/schema.sql' | $(COMPOSE) exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb
	Get-Content -Raw 'db/seed/mock_data.sql' | $(COMPOSE) exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb

lint:
	Set-Location 'demo-app'; & '$(NPM)' run lint

app-test:
	Set-Location 'demo-app'; & '$(NPM)' test

validate:
	& '$(PYTHON)' 'db/seed/validate_overlay.py' '$(FILE)'

test:
	& '$(PYTHON)' -m pytest 'tests/test_validate_overlay.py' -q
	& '$(GIT_BASH)' 'tests/test_delta_detect.sh'

authz:
	& '$(GIT_BASH)' 'scripts/authz-tests.sh' 'http://127.0.0.1:8080'

dast:
	& '$(GIT_BASH)' 'scripts/run-dast-local.sh'

clean:
	$(COMPOSE) down -v --remove-orphans
