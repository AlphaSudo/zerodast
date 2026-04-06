SHELL := C:/Program Files/PowerShell/7/pwsh.exe
.SHELLFLAGS := -NoProfile -Command

ENGINE_EXE ?=
COMPOSE_EXE ?=
PYTHON = C:\Users\CM\AppData\Local\Programs\Python\Python311\python.exe
GIT_BASH = C:\Program Files\Git\bin\bash.exe
NPM = C:\Users\CM\AppData\Roaming\fnm\node-versions\v22.15.0\installation\npm.cmd
APP_IMAGE = zerodast-demo-app:local

.PHONY: build up seed dast validate test authz clean lint app-test

build:
	if ('$(COMPOSE_EXE)') { & '$(COMPOSE_EXE)' build app } else { docker compose build app }

up:
	if ('$(COMPOSE_EXE)') { & '$(COMPOSE_EXE)' up -d db app } else { docker compose up -d db app }

seed:
	$composeCmd = if ('$(COMPOSE_EXE)') { '$(COMPOSE_EXE)' } else { $null }; $schema = Get-Content -Raw 'db/seed/schema.sql'; $mock = Get-Content -Raw 'db/seed/mock_data.sql'; if ($composeCmd) { $schema | & $composeCmd exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb; $mock | & $composeCmd exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb } else { $schema | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb; $mock | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U testuser -d testdb }

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
	if ('$(ENGINE_EXE)') { $env:CONTAINER_ENGINE_BIN = '$(ENGINE_EXE)' }; & '$(GIT_BASH)' 'scripts/run-dast-local.sh'

clean:
	if ('$(COMPOSE_EXE)') { & '$(COMPOSE_EXE)' down -v --remove-orphans } else { docker compose down -v --remove-orphans }