# Competitions

LEGO crafting competition platform for Suomen Palikkaharrastajat ry.

The project has three moving parts:

- **Custom PocketBase 0.37.5 backend** stores competitions, entries, reviews, shared profiles, local OTP users, Keycloak users, and uploaded entry images.
- **Elm 0.19.1 SPA** provides participant and reviewer workflows: Keycloak login, local OTP login, entry submission, own entries, and review tools.
- **Haskell gallery pipeline** reads approved PocketBase data and writes a static gallery snapshot.

## Local Development

Use `devenv` for the pinned toolchain and services:

```bash
devenv shell
devenv up
```

`devenv up` starts the full local stack and applies both schema migrations and local-only fixture migrations:

| URL | Service |
| --- | --- |
| `http://127.0.0.1:8080/` | Elm SPA through Caddy |
| `http://127.0.0.1:8080/_/` | PocketBase admin UI |
| `http://127.0.0.1:8080/api/` | PocketBase REST API |
| `http://127.0.0.1:8080/mailpit/` | Mailpit email UI |
| `http://127.0.0.1:8081/realms/competitions/` | Keycloak realm |
| `http://127.0.0.1:8090/` | PocketBase direct |
| `http://127.0.0.1:5173/` | Vite direct |

Copy `.env.example` to `.env` when running commands that need `POCKETBASE_URL` or `POCKETBASE_API_KEY`.

To generate a local `.env` with a working PocketBase superuser API key:

```bash
make .env
```

The target initializes the local devenv PocketBase data directory if needed, creates or updates a local superuser, mints a verified API key, and writes `.env`.

### PocketBase API Key

`POCKETBASE_API_KEY` is a PocketBase superuser API key used by the Haskell gallery pipeline when it needs admin-only data such as user display names.

To create it locally:

1. Start the stack with `devenv up`.
2. Open `http://127.0.0.1:8080/_/`.
3. Sign in as a PocketBase superuser.
4. Go to **Settings -> API keys**.
5. Create a new API key and give it a clear local name, such as `competitions-local-gallery`.
6. Copy the generated key into `.env`:

```bash
POCKETBASE_URL=http://127.0.0.1:8080
POCKETBASE_API_KEY=your-generated-key
```

If the admin UI does not prompt you to create the first superuser, create one with the PocketBase CLI against the same data directory used by `devenv up`:

```bash
PB_SUPERUSER_EMAIL=admin@example.test \
PB_SUPERUSER_PASSWORD='change-this-local-password' \
make pb-superuser
```

Then sign in at `http://127.0.0.1:8080/_/` with that email and password. You can run `make pb-superuser` again with the same email to reset the local superuser password.

The gallery can run without this key against public data, but submitter display names from the `profiles` collection are only available when the key is set.

## Authentication Model

Participant and reviewer ownership lives in `profiles`, not directly in an auth collection. `entries.submitter` and `reviews.reviewer` point at profile records.

- `keycloak_users`: Keycloak/OIDC auth only.
- `local_users`: email OTP auth only.
- `profiles`: shared identity, normalized email, display name, reviewer flag, and links to auth records.

Keycloak wins for matching emails. If an email already exists in `keycloak_users`, local OTP returns `409 keycloak_required` and no OTP is sent. If Keycloak login later creates a matching `keycloak_users` record, any matching local user is blocked from future OTP login.

## Demo Fixture

Local fixture data lives in `pb_migrations_dev/` and is never for production. It is applied automatically by `devenv up` after the schema migrations.

Seeded local users:

| Email | Role |
| --- | --- |
| `participant@example.test` | verified participant |
| `reviewer@example.test` | verified reviewer |
| `johndoe@example.com` | verified local participant |
| `janedoe@example.com` | verified local participant |

Seeded Keycloak users:

| Email | Password | Role |
| --- | --- | --- |
| `keycloak-participant@example.test` | `participant` | participant |
| `keycloak-reviewer@example.test` | `reviewer` | reviewer |

Seeded data:

- One open competition: `Avaruusasema 2026`
- One finished competition: `Talvikaupunki 2025`
- Draft, submitted, approved, and rejected entries
- Tiny PNG fixture images attached to entries
- Published review data for the gallery and unpublished review data for reviewer flow testing
- Mailpit SMTP settings for OTP email in local development

## Common Commands

```bash
make test             # run Haskell checks/tests and Elm tests
make elm-test         # run Elm tests only
make gallery-run      # generate static gallery output from PocketBase
make pb-test-migrate  # smoke-test schema migrations
make pb-test-fixture  # smoke-test schema + local fixture migrations
make pb-test-auth-policy # smoke-test Keycloak-first OTP hooks
make pb-seed          # apply local-only fixture migrations to pb_data/
```

## Architecture Rules

PocketBase is the data source of truth. The Elm app and Haskell gallery both use the PocketBase REST API; they do not call each other. Schema changes belong in `pb_migrations/`. Local fixture data belongs in `pb_migrations_dev/` and must not be deployed to production. Hooks for the custom backend live in `pb_hooks/`.

Agents should start with `AGENTS.md`, then ADRs in `agents/adrs/`, user stories in `agents/stories/`, and finally tests.
