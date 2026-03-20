# Palikkakilpailu — Repository Orientation

## 1. What This System Is

A LEGO MOC competition platform for Suomen Palikkaharrastajat ry. Participants submit MOC entries, reviewers score them, and a static gallery is generated from the results.

**Components:**
- **PocketBase** (≥ 0.22) — SQLite backend, OTP-only auth, file storage, REST API
- **Elm 0.19.1 + TailwindCSS v4 + Vite** — participant and reviewer SPA
- **Haskell (GHC 9.6) + blaze-html** — static gallery pipeline

## 2. First-Run Setup

```
1.  Clone repository
2.  Install devenv: https://devenv.sh/getting-started/
3.  devenv shell       (or: make develop for devcontainer setup)
4.  cp .env.example .env
5.  devenv up          ← starts PocketBase (port 8090) + Elm dev server (port 5173)
6.  Open http://127.0.0.1:8090/_/ → create superuser account when prompted
7.  Settings → API Keys → New API key → paste into .env as POCKETBASE_API_KEY
8.  cp elm-app/.env.example elm-app/.env
9.  make test                        ← run Haskell tests
10. cd elm-app && npm test           ← run Elm tests
11. make pb-seed                     ← (optional) load dev seed competition
```

`devenv up` runs PocketBase with `--dev`, which logs OTP codes to the console — no SMTP needed for local development.

## 3. Common Commands

```bash
devenv up                    # start PocketBase (8090) + Elm dev server (5173)
make test                    # hlint + cabal test (Haskell)
cd elm-app && npm test       # elm-test (Elm)
make pb-test-migrate         # smoke-test migrations against a throwaway pb_data dir
make pb-seed                 # apply dev seed data (pb_migrations_dev/) — local only
make pb-configure            # enable OTP + disable password auth via PocketBase API
make gallery-run             # generate dist/index.html (requires devenv up first)
```

## 4. Migration Directories

| Directory | Purpose |
|-----------|---------|
| `pb_migrations/` | Schema migrations — run in all environments |
| `pb_migrations_dev/` | Dev seed data — run locally only, **never in production** |

## 5. Production Deployment

### SMTP Setup (required for OTP email delivery)
1. Open PocketBase Admin UI → Settings → Mail
2. Configure SMTP server credentials
3. Test with Settings → Mail → Send test email

Without SMTP, OTP login will not work in production. In local dev, OTP codes appear in the PocketBase console output instead (when running with `--dev`).

### PocketBase Auth Configuration
Run `make pb-configure` once after first deployment to enable OTP and disable password auth.
Requires `POCKETBASE_URL`, `PB_SUPERUSER_EMAIL`, and `PB_SUPERUSER_PASSWORD` to be set in the environment.

## 6. Agent Reading Order

1. `AGENTS.md` — rules of engagement, repository map, build commands
2. `agents/adrs/` — architectural decisions and constraints
3. `agents/GLOSSARY.md` — Finnish/English domain vocabulary
4. `tests/` and `elm-app/tests/` — the authoritative source of truth for behavior
5. `src/` and `elm-app/src/` — implementation

**Precedence:** Tests > ADRs > User Stories > Implementation Comments
