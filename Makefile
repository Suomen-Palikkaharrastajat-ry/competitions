HLINT ?= hlint
FOURMOLU ?= fourmolu
ELM_REVIEW ?= elm-review
COMPETITION_NIX ?= competition-nix
POCKETBASE ?= env GOFLAGS=-mod=mod go run ./cmd/competition-pocketbase

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── Vendor / submodules ──────────────────────────────────────────────────────

.PHONY: vendor
vendor: ## Init and update all git submodules to their pinned commits
	@# In CI environments (GitHub Actions) SSH access is unavailable;
	@# rewrite git@github.com: to https://github.com/ so submodules clone via HTTPS.
	@[ -z "$$CI" ] || git config --global url."https://github.com/".insteadOf "git@github.com:"
	@# Fall back to a plain clone when this tree is not a git checkout (source
	@# tarball, vendored copy). The submodule directory itself always exists, so
	@# probe for a file inside it rather than for the directory.
	@if [ -d .git ]; then git submodule update --init; \
	elif [ ! -e vendor/master-builder/AGENTS.md ]; then \
		mkdir -p vendor && git clone https://github.com/Suomen-Palikkaharrastajat-ry/master-builder.git vendor/master-builder; \
	fi

# ── Development environment ──────────────────────────────────────────────────

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: .env
.env: ## Generate local .env with a working PocketBase superuser API key
	POCKETBASE='$(POCKETBASE)' bash scripts/generate-env.sh

.PHONY: develop
develop: devenv.local.nix devenv.local.yaml ## Bootstrap opinionated development environment
	devenv shell --profile=devcontainer -- code .

devenv.local.nix:
	cp devenv.local.nix.example devenv.local.nix

devenv.local.yaml:
	cp devenv.local.yaml.example devenv.local.yaml

# ── Elm frontend ──────────────────────────────────────────────────────────────

# Vite must not write its temp config into the read-only node_modules.
VITE_FLAGS ?= --configLoader runner

# The shared targets `site-config` and `site-config-check` come from the hub.
SITE_CONFIG_I18N := elm-app/src elm-app/main.js statics/src statics/app

-include vendor/master-builder/mk/site-config.mk

.PHONY: elm-dev
elm-dev: ## Start Elm + Vite dev server (hot reload)
	cd elm-app && vite $(VITE_FLAGS)

ELM_APP_SOURCES := $(shell find elm-app/src -name '*.elm')
ELM_PACKAGE_SOURCES := $(shell find vendor/master-builder/packages -name '*.elm' -o -name '*.css' 2>/dev/null)

.PHONY: elm-tailwind-gen
elm-tailwind-gen: elm-app/.elm-tailwind/.stamp ## Generate typed Tailwind Elm modules into elm-app/.elm-tailwind/

elm-app/.elm-tailwind/.stamp: elm-app/elm.json elm-app/vite.config.mjs elm-app/main.css $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES)
	cd elm-app && elm-tailwind-classes gen
	mkdir -p elm-app/.elm-tailwind
	touch $@

# The app builds into dist/ (emptied first); the gallery goes to
# dist/galleria/ after it (competition.toml output_dir).
dist/.elm-stamp: elm-app/.elm-tailwind/.stamp $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES) elm-app/elm.json elm-app/vite.config.mjs elm-app/index.html elm-app/main.js elm-app/main.css $(SITE_CONFIG_DEPS)
	cd elm-app && vite build $(VITE_FLAGS)
	touch $@

.PHONY: elm-build
elm-build: dist/.elm-stamp ## Build the Elm app into dist/

.PHONY: elm-test
elm-test: elm-tailwind-gen ## Run Elm unit tests
	node --test elm-app/tests/*.test.mjs
	cd elm-app && elm-test

.PHONY: elm-check
elm-check: site-config-check elm-tailwind-gen ## Check Elm formatting, elm-review rules and display-text placement (no changes)
	cd elm-app && elm-format --validate src/ tests/
	cd elm-app && $(ELM_REVIEW) --config ../review --ignore-dirs .elm-tailwind

.PHONY: elm-quality
elm-quality: elm-check elm-test ## Run non-browser Elm quality gates

.PHONY: elm-format
elm-format: ## Auto-format Elm source files
	cd elm-app && elm-format --yes src/

# ── Haskell gallery pipeline ──────────────────────────────────────────────────

# The package lives in statics/ (cabal.project), like the other apps' static
# generators; the binary is copied to ./competition, run from the repository
# root (it reads competition.toml).
HS_SOURCES := $(shell find statics/src statics/app -name '*.hs') statics/competition.cabal $(wildcard cabal.project*)

competition: $(HS_SOURCES)
	cabal build competition
	cp $$(cabal list-bin exe:competition) $@

.PHONY: gallery-build statics-build
gallery-build: competition ## Build Haskell gallery pipeline
statics-build: competition ## Build Haskell gallery pipeline (the family's target name)

# The gallery depends on PocketBase data, not on files: it is rebuilt every
# time, after the app build that empties dist/.
.PHONY: gallery-run
gallery-run: competition dist/.elm-stamp ## Generate the gallery into dist/galleria/ (requires POCKETBASE_URL)
	./competition

.PHONY: gallery-ci
gallery-ci: dist/.elm-stamp ## Generate the gallery with the Nix-built pipeline (production PocketBase)
	POCKETBASE_URL=https://data.palikkaharrastajat.fi $(COMPETITION_NIX)

.PHONY: repl
repl: ## Start the Haskell REPL
	cabal repl competition

.PHONY: cabal-check
cabal-check: ## Check the package for common Cabal metadata errors
	cd statics && cabal check

# ── Combined targets ──────────────────────────────────────────────────────────

.PHONY: dist-ci
dist-ci: gallery-ci ## CI build into dist/: the app and the gallery (Nix-built pipeline)

.PHONY: dist
dist: gallery-run ## Full local build into dist/: the app and the gallery

.PHONY: watch
watch: ## Watch for changes in Haskell and Elm files and rebuild
	make gallery-run
	find statics competition.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make gallery-run' &
	cd elm-app && elm-tailwind-classes gen && vite

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: haskell-check
haskell-check: ## Check Haskell formatting and run hlint (no changes)
	$(HLINT) statics/src statics/app statics/tests
	find statics -name '*.hs' | xargs $(FOURMOLU) --mode check

.PHONY: statics-check statics-test
statics-check: haskell-check ## Lint Haskell source (the family's target name)
statics-test: ## Run Haskell tests
	cabal test competition-tests

.PHONY: check
check: haskell-check elm-check ## Check Haskell and Elm static quality gates

.PHONY: hs-coverage
hs-coverage: ## Run Haskell tests with Cabal/HPC coverage enabled
	cabal test --enable-coverage
	@echo "Haskell coverage report generated under dist-newstyle/**/t/competition-tests/hpc/vanilla/html/"

.PHONY: quality
quality: haskell-check cabal-check ## Run strict non-browser quality gates for CI
	cabal test
	$(MAKE) elm-quality
	$(MAKE) pb-test-migrate
	$(MAKE) pb-test-fixture
	$(MAKE) dev-proxy-test

.PHONY: test
test: check ## Run Haskell and Elm tests
	cabal test
	$(MAKE) elm-test

.PHONY: dev-proxy-test
dev-proxy-test: ## Smoke-test local reverse proxy configuration
	@./scripts/test-dev-proxy-config.sh

.PHONY: format
format: ## Auto-format Haskell and Elm source files
	find src tests -name '*.hs' | xargs $(FOURMOLU) --mode inplace
	$(MAKE) elm-format
	treefmt

# ── PocketBase ────────────────────────────────────────────────────────────────

.PHONY: pb-dev
pb-dev: ## Start a local PocketBase server (data in pb_data/, hot-reload admin UI)
	rm -f ./pb_migrations/types.d.ts
	PB_MIGRATIONS_DIR=./pb_migrations PB_HOOKS_DIR=./pb_hooks $(POCKETBASE) serve --dir ./pb_data --dev

.PHONY: pb-migrate
pb-migrate: ## Apply pending PocketBase migrations against pb_data/
	rm -f ./pb_migrations/types.d.ts
	PB_MIGRATIONS_DIR=./pb_migrations $(POCKETBASE) migrate up --dir ./pb_data

.PHONY: pb-seed
pb-seed: ## Apply dev seed data against local pb_data/ (never run in production)
	PB_MIGRATIONS_DIR=./pb_migrations_dev $(POCKETBASE) migrate up --dir ./pb_data

.PHONY: pb-configure
pb-configure: ## Configure PocketBase mailpit SMTP (requires POCKETBASE_URL + POCKETBASE_API_KEY)
	@test -n "$$POCKETBASE_URL"    || (echo "POCKETBASE_URL not set"; exit 1)
	@test -n "$$POCKETBASE_API_KEY" || (echo "POCKETBASE_API_KEY not set"; exit 1)
	@curl -sf -X PATCH "$$POCKETBASE_URL/api/settings" \
	  -H "Authorization: Bearer $$POCKETBASE_API_KEY" \
	  -H "Content-Type: application/json" \
	  -d '{"smtp":{"enabled":true,"host":"127.0.0.1","port":1025,"username":"","password":"","tls":false},"meta":{"senderName":"Palikkakilpailu","senderAddress":"noreply@palikkaharrastajat.fi"}}' \
	  | python3 -c "import sys,json; d=json.load(sys.stdin); print('pb-configure: PASS' if d.get('smtp') else 'pb-configure: FAIL')"

.PHONY: pb-superuser
pb-superuser: ## Create/update local devenv PocketBase superuser (requires PB_SUPERUSER_EMAIL + PB_SUPERUSER_PASSWORD)
	@test -n "$$PB_SUPERUSER_EMAIL" || (echo "PB_SUPERUSER_EMAIL not set"; exit 1)
	@test -n "$$PB_SUPERUSER_PASSWORD" || (echo "PB_SUPERUSER_PASSWORD not set"; exit 1)
	$(POCKETBASE) superuser upsert "$$PB_SUPERUSER_EMAIL" "$$PB_SUPERUSER_PASSWORD" --dir ./.devenv/state/pocketbase/data

.PHONY: pb-test-migrate
pb-test-migrate: ## Smoke-test all migrations against a throwaway data dir (no state left behind)
	@rm -f ./pb_migrations/types.d.ts && \
	  PBTEST=$$(mktemp -d) && \
	  PBLOG=$$(mktemp) && \
	  if PB_MIGRATIONS_DIR=./pb_migrations $(POCKETBASE) migrate up --dir $$PBTEST > $$PBLOG 2>&1; then \
	    grep -v DEBUG $$PBLOG || true; \
	    if grep -q '^Error:' $$PBLOG; then rm -rf $$PBTEST $$PBLOG; exit 1; fi; \
	  else \
	    grep -v DEBUG $$PBLOG || true; \
	    rm -rf $$PBTEST $$PBLOG; \
	    exit 1; \
	  fi && \
	  rm -rf $$PBTEST && rm -f ./pb_migrations/types.d.ts && \
	  rm -f $$PBLOG && \
	  echo "pb-test-migrate: PASS"

.PHONY: pb-test-fixture
pb-test-fixture: ## Smoke-test schema + dev fixture migrations against a throwaway data dir
	@rm -f ./pb_migrations/types.d.ts ./pb_migrations_dev/types.d.ts && \
	  PBTEST=$$(mktemp -d) && \
	  PBLOG=$$(mktemp) && \
	  if PB_MIGRATIONS_DIR=./pb_migrations $(POCKETBASE) migrate up --dir $$PBTEST > $$PBLOG 2>&1; then \
	    grep -v DEBUG $$PBLOG || true; \
	    if grep -q '^Error:' $$PBLOG; then rm -rf $$PBTEST $$PBLOG; exit 1; fi; \
	  else \
	    grep -v DEBUG $$PBLOG || true; \
	    rm -rf $$PBTEST $$PBLOG; \
	    exit 1; \
	  fi && \
	  if PB_MIGRATIONS_DIR=./pb_migrations_dev $(POCKETBASE) migrate up --dir $$PBTEST > $$PBLOG 2>&1; then \
	    grep -v DEBUG $$PBLOG || true; \
	    if grep -q '^Error:' $$PBLOG; then rm -rf $$PBTEST $$PBLOG; exit 1; fi; \
	  else \
	    grep -v DEBUG $$PBLOG || true; \
	    rm -rf $$PBTEST $$PBLOG; \
	    exit 1; \
	  fi && \
	  rm -rf $$PBTEST && rm -f ./pb_migrations/types.d.ts ./pb_migrations_dev/types.d.ts && \
	  rm -f $$PBLOG && \
	  echo "pb-test-fixture: PASS"

.PHONY: pb-test-auth-policy
pb-test-auth-policy: ## Smoke-test Keycloak-first OTP policy hooks
	@POCKETBASE='$(POCKETBASE)' ./scripts/test-auth-policy.sh

.PHONY: pb-test-entry-limits
pb-test-entry-limits: ## Smoke-test the entry image limit hooks
	@POCKETBASE='$(POCKETBASE)' ./scripts/test-entry-limits.sh

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts and output
	cabal clean
	rm -rf dist competition .hpc *.html elm-app/.elm-tailwind
