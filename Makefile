.PHONY: help all dist gallery-run gallery-bin clean test repl check cabal-check watch pb-dev pb-migrate pb-test-migrate pb-configure develop

default: help

all: dist ## Build the entire project

dist: ## Build Haskell pipeline and Elm app
	cabal build
	cd elm-app && npm run build

gallery-run: ## Run the gallery pipeline (requires POCKETBASE_URL)
	cabal run competition

gallery-bin: ## Run the compiled gallery binary directly
	./competition

.PHONY: develop
develop: devenv.local.nix devenv.local.yaml ## Bootstrap opinionated development environment
	devenv shell --profile=devcontainer -- code .

devenv.local.nix:
	cp devenv.local.nix.example devenv.local.nix

devenv.local.yaml:
	cp devenv.local.yaml.example devenv.local.yaml

clean: ## Clean build artifacts and output
	cabal clean
	rm -rf dist-newstyle competition .hpc *.html

test: check ## Run all tests (hlint + cabal test + elm test)
	cabal test
	cd elm-app && npm test

repl: ## Start the Haskell REPL
	cabal repl

check: ## Run hlint static analysis
	hlint src tests

cabal-check: ## Check the package for common errors
	cabal check

watch: ## Watch for changes and rebuild
	find src competition.cabal competition.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make gallery-run' &
	cd elm-app && npm run dev

pb-dev: ## Start a local PocketBase server (data in pb_data/, hot-reload admin UI)
	rm -f ./pb_migrations/types.d.ts
	pocketbase serve --dir ./pb_data --migrationsDir ./pb_migrations --dev

pb-migrate: ## Apply pending PocketBase migrations against pb_data/
	rm -f ./pb_migrations/types.d.ts
	pocketbase migrate up --dir ./pb_data --migrationsDir ./pb_migrations

pb-configure: ## Configure PocketBase OTP auth via admin API (requires PB_SUPERUSER_EMAIL + PB_SUPERUSER_PASSWORD + POCKETBASE_URL)
	@test -n "$$POCKETBASE_URL"       || (echo "POCKETBASE_URL not set"; exit 1)
	@test -n "$$PB_SUPERUSER_EMAIL"   || (echo "PB_SUPERUSER_EMAIL not set"; exit 1)
	@test -n "$$PB_SUPERUSER_PASSWORD" || (echo "PB_SUPERUSER_PASSWORD not set"; exit 1)
	@TOKEN=$$(curl -s -X POST "$$POCKETBASE_URL/api/admins/auth-with-password" \
	  -H "Content-Type: application/json" \
	  -d "{\"identity\":\"$$PB_SUPERUSER_EMAIL\",\"password\":\"$$PB_SUPERUSER_PASSWORD\"}" \
	  | grep -o '"token":"[^"]*"' | cut -d'"' -f4) && \
	curl -s -X PATCH "$$POCKETBASE_URL/api/collections/users" \
	  -H "Authorization: $$TOKEN" \
	  -H "Content-Type: application/json" \
	  -d '{"passwordAuth":{"enabled":false},"otp":{"enabled":true,"duration":600,"length":6}}' \
	  | grep -q '"id"' && echo "pb-configure: PASS" || echo "pb-configure: FAIL"

pb-test-migrate: ## Smoke-test all migrations against a throwaway data dir (no state left behind)
	@rm -f ./pb_migrations/types.d.ts && \
	  PBTEST=$$(mktemp -d) && \
	  pocketbase migrate up --dir $$PBTEST --migrationsDir ./pb_migrations 2>&1 | grep -v DEBUG && \
	  rm -rf $$PBTEST && rm -f ./pb_migrations/types.d.ts && \
	  echo "pb-test-migrate: PASS"

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
