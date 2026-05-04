# AGENTS.md

## Purpose

This document defines how LLM coding agents must read, navigate, and safely modify the `competitions` repository. It is the primary entry point for any agent-based task.

This repository is a LEGO crafting competition platform for Suomen Palikkaharrastajat ry:

- **Custom PocketBase 0.37.5** is the backend for competitions, entries, reviews, shared profiles, Keycloak/OIDC auth, local OTP auth, and uploaded images.
- **Elm 0.19.1** is the interactive SPA for participants and reviewers.
- **Haskell** builds the static public gallery from approved PocketBase data.

---

## 1. Source of Truth & Precedence

Your understanding and actions must be guided by the following artifacts, in this strict order of precedence:

1.  **Tests (`tests/` and `elm-app/tests/`)**: Define the verifiable, correct behavior of the application. **Tests are the ultimate source of truth.**
2.  **ADRs (`agents/adrs/`)**: Define the architectural constraints and non-negotiable rules.
3.  **User Stories (`agents/stories/`)**: Explain the "why" behind the features and define product intent.
4.  **Glossary (`agents/GLOSSARY.md`)**: Provides the canonical vocabulary for this project.
5.  **TODO files (`TODO-00-cleanup.md` through `TODO-08-fixes.md`)**: Define the implementation plan in sequential order. Read the relevant TODO before working on any feature.
6.  **Inline Source Code Comments**: Provide context but are subordinate to the artifacts above.

---

## 2. Agent Self-Guidance Work Loop

Before making any changes, you **MUST** follow this work loop:

1.  **State Goal**: Clearly state the perceived goal of the task.
2.  **Read the TODO**: Find and read the TODO file (`TODO-XX-*.md`) relevant to your task.
3.  **Locate Artifacts**: Identify and read all relevant tests, user stories, and ADRs related to the goal.
4.  **Identify Constraints**: List the specific architectural and behavioral constraints imposed by the artifacts.
5.  **Propose Strategy**: Formulate a minimal change strategy that respects all constraints.
6.  **Formalize Behavior (BDD)**: When adding or updating tests, express the desired behavior in a Given/When/Then format within the test's comments or the user story itself.
7.  **Update/Add Tests**: Before writing implementation code, add or update tests that codify the goal. Ensure they fail as expected.
8.  **Implement**: Write the code to make the new tests pass.
9.  **Verify**: Run all tests and re-evaluate your changes against the user stories and ADRs to ensure compliance.

---

## 3. Repository Map (Agent-Oriented)

```
competitions/
├── AGENTS.md                   ← You are here. Defines rules of engagement.
├── README.md                   ← Human-facing project overview and first-run guide
├── TODO-00-cleanup.md          ← Step 0: Remove planet/feed code; rename project
├── TODO-01-pocketbase-schema.md← Step 1: PocketBase collections (migrations)
├── TODO-02-elm-auth.md         ← Step 2: OTP login in Elm app
├── TODO-03-elm-submit.md       ← Step 3: Entry submission flow
├── TODO-04-elm-review.md       ← Step 4: Reviewer tools
├── TODO-05-haskell-gallery.md  ← Step 5: Haskell static gallery pipeline
├── TODO-06-devenv.md           ← Step 6: Developer environment
├── TODO-07-missing-features.md ← Step 7: Admin tools, accessibility, SMTP, scores, error boundaries
├── TODO-08-fixes.md            ← Step 8: Security, quality, and test gap fixes
├── competition.toml            ← Gallery pipeline config (title, locale, timezone)
├── competition.cabal           ← Haskell project (after TODO-00)
├── Makefile                    ← Build targets
├── Caddyfile                   ← Local reverse proxy: app, PocketBase, Mailpit on port 8080
├── overlays.nix                ← PocketBase 0.37.5 package pin
├── go.mod / go.sum             ← Custom PocketBase wrapper dependencies
├── .env / .env.example         ← POCKETBASE_URL + POCKETBASE_API_KEY
│
├── src/                        ← Haskell source
│   ├── Main.hs                 ← Entry point (runs gallery pipeline)
│   ├── Config.hs               ← TOML config parser
│   ├── GalleryTypes.hs         ← Domain types: Competition, Entry, Review, RankedEntry
│   ├── GalleryFetcher.hs       ← Fetch data from PocketBase REST API
│   ├── GalleryGen.hs           ← Render blaze-html gallery page
│   ├── GalleryElmData.hs       ← (optional) Generate Elm data module
│   ├── PocketBase.hs           ← Generic PocketBase HTTP client (reusable)
│   ├── HtmlSanitizer.hs        ← HTML sanitization (for entry descriptions)
│   ├── Styles.hs               ← Inlined CSS with brand design tokens
│   ├── Scripts.hs              ← Inlined JS (lightbox, etc.)
│   └── I18n.hs                 ← Finnish/English labels and date formatting
│
├── tests/                      ← Haskell test suite
│   ├── TestSuite.hs            ← Test suite entry point
│   ├── ConfigSpec.hs           ← Config parsing tests
│   ├── GalleryFetcherSpec.hs   ← Ranking algorithm + HTTP integration tests
│   └── GalleryGenSpec.hs       ← HTML generation tests
│
├── elm-app/                    ← Elm web application (participant + reviewer UI)
│   ├── src/
│   │   ├── Main.elm            ← App entry point (The Elm Architecture)
│   │   ├── Types.elm           ← Model, Msg, AuthState, Page, Competition, Entry, Review
│   │   ├── View.elm            ← All page views and UI components
│   │   ├── Ports.elm           ← JS interop (auth persistence)
│   │   └── main.css            ← TailwindCSS v4 with @theme brand tokens
│   ├── tests/                  ← Elm test suite (elm-test)
│   │   ├── AuthTest.elm
│   │   ├── SubmitFormTest.elm
│   │   ├── ReviewTest.elm
│   │   └── DecoderTest.elm
│   ├── index.html              ← App shell
│   ├── src/main.js             ← Vite entrypoint (flags: pbUrl, restoredAuth)
│   ├── elm.json
│   ├── src/main.js             ← Vite entrypoint + PocketBase JS OAuth helper
│   └── packages → ../vendor/master-builder/packages
│
├── cmd/competition-pocketbase/ ← Go wrapper that registers PB JS migrations/hooks
├── pb_hooks/                   ← PocketBase JSVM hooks for Keycloak-first auth
│
├── pb_migrations/              ← PocketBase schema migrations (all environments)
│   ├── 001_create_competitions.js
│   ├── 002_create_entries.js
│   ├── 003_create_reviews.js
│   ├── 004_extend_users.js
│   ├── 005_restrict_competitions_write.js
│   ├── 006_restrict_users_update.js
│   └── 007_dual_auth_profiles.js
├── pb_migrations_dev/          ← Local-only fixture/settings migrations (never production)
│   ├── 001_seed_competition.js
│   ├── 002_configure_mailpit_smtp.js
│   ├── 003_seed_demo_fixture.js
│   ├── 004_seed_local_participants.js
│   └── 005_seed_keycloak_shadow_users.js
├── keycloak/
│   └── competitions-realm.json ← Local Keycloak realm/client/users fixture
│
├── pb_data/                    ← PocketBase runtime data (gitignored)
├── .devenv/state/pocketbase/   ← devenv PocketBase runtime data (gitignored)
│
├── agents/
│   ├── GLOSSARY.md             ← Canonical vocabulary
│   ├── README.md               ← Quick repo orientation + first-run guide
│   └── adrs/
│       ├── ADR-0000-agent-guidance.md
│       ├── ADR-0001-pocketbase.md
│       ├── ADR-0002-competition-architecture.md
│       └── ADR-0003-dual-auth-keycloak.md
│
└── devenv.nix                  ← Nix devenv: GHC, Elm/Vite tools, Go/PocketBase, Caddy, Mailpit, Keycloak
```

---

## 4. Change Rules

- **Do not** modify application behavior without first adding or modifying a test.
- **Do not** violate a constraint defined in an ADR. If a change requires this, propose a new ADR first.
- All code changes must be accompanied by corresponding test updates.
- All commit messages **MUST** follow Conventional Commits (see ADR-0000).
- **Do not** hard-code raw hex color values, pixel values, or font names — always use brand design tokens (see §6).
- **Do not** put production schema or data changes in `pb_migrations_dev/`; it is local fixture data only.
- **Do not** deploy or run `pb_migrations_dev/` in production. Production uses `pb_migrations/` only.

---

## 5. Decision Escalation Rules

You **MUST STOP** and escalate to the user if:

- A requirement in a User Story conflicts with an existing test.
- A proposed change would violate an ADR constraint.
- The desired behavior is ambiguous.
- You are uncertain how to proceed.

**Escalation procedure:** Document the conflict clearly; if possible create a failing test that demonstrates the ambiguity; ask the user for clarification. **Do not guess.**

---

## 6. Style Guide Compliance

This project follows the **Suomen Palikkaharrastajat ry** brand style guide.

- **Agent CSS reference:** Fetch `https://logo.palikkaharrastajat.fi/brand.css` for the latest canonical `@theme`, `@utility type-*`, `@font-face`, reduced-motion rule, and shared component classes. Tailwind v4 requires `@theme` in the locally-processed file — copy the content into `elm-app/src/main.css`.
- **Human-readable:** https://logo.palikkaharrastajat.fi/
- **Machine-readable (JSON-LD):** https://logo.palikkaharrastajat.fi/design-guide/index.jsonld
  - Colors: https://logo.palikkaharrastajat.fi/design-guide/colors.jsonld
  - Typography: https://logo.palikkaharrastajat.fi/design-guide/typography.jsonld
  - Spacing: https://logo.palikkaharrastajat.fi/design-guide/spacing.jsonld
  - Motion: https://logo.palikkaharrastajat.fi/design-guide/motion.jsonld
  - Logos: https://logo.palikkaharrastajat.fi/design-guide/logos.jsonld
  - Responsiveness: https://logo.palikkaharrastajat.fi/design-guide/responsiveness.jsonld

**When making any UI change**, you MUST:

1. **Check the live design guide first** (`https://logo.palikkaharrastajat.fi/`). Any color, font, spacing, or animation value must come from a named design token — never hard-code raw hex values or pixel values.
2. **Use brand colors correctly:**
   - Primary brand color is `#05131D` (brand black).
   - Brand accent is `#FAC80A` (yellow) — only for CTAs/highlights, always paired with brand-black text.
   - Red `#C91A09` is for danger/error/reject states only.
   - Use semantic Tailwind classes: `bg-bg-dark`, `text-text-on-dark`, `bg-bg-accent`, `border-border-default`, etc.
3. **Use named `type-*` utility classes** for all text (defined in `elm-app/src/main.css`). Never use raw Tailwind size/weight combinations.

   | Class | Size | Weight | Notes |
   |---|---|---|---|
   | `type-display` | 3rem | 700 | Hero headlines only |
   | `type-h1` | 1.875rem | 700 | One per page |
   | `type-h2` | 1.5rem | 700 | Section headings |
   | `type-h3` | 1.25rem | 600 | Sub-section headings |
   | `type-h4` | 1.125rem | 600 | Card / widget headings |
   | `type-body` | 1rem | 400 | Default body copy |
   | `type-body-small` | 0.875rem | 500 | UI controls, labels |
   | `type-caption` | 0.875rem | 400 | Metadata, footnotes |
   | `type-mono` | 0.875rem | 400 | Code snippets (monospace) |
   | `type-overline` | 0.75rem | 600 uppercase | Category labels |

4. **Use Outfit font exclusively** (variable font, weight 100–900; OFL licensed). Self-hosted from `elm-app/public/fonts/`.
5. **Respect logo usage rules:** SVG preferred; minimum 80px wide; 25% clear space; no stretching or recolouring.
6. **Use named spacing tokens** (4px base: `space-1` through `space-16`); never use arbitrary px values.
7. **Respect motion rules:** `transform`/`opacity` only; `@media (prefers-reduced-motion: no-preference)`; `duration-fast` = 150ms; `duration-base` = 300ms; `ease-standard = cubic-bezier(0.4, 0, 0.2, 1)`.
8. **Use `focus-visible:ring-2`** (not `focus:ring-2`) on all interactive elements.
9. **Page layout**: `max-w-5xl mx-auto px-4`. Cards: `rounded-lg` (8px radius).

---

## 7. Build & Test Commands

```bash
# Haskell
make test              # hlint + cabal test
make gallery-run       # generate dist/index.html (requires POCKETBASE_URL)
cabal repl             # interactive REPL

# Elm
make elm-test          # elm-test via Nix-provided tooling
make elm-dev           # Vite dev server at localhost:5173
make elm-build         # production Elm/Vite build

# PocketBase
make pb-dev            # start PocketBase in dev mode
make pb-migrate        # apply pending migrations
make pb-test-migrate   # smoke-test migrations against throwaway dir
make pb-test-fixture   # smoke-test schema + local fixture migrations
make pb-test-auth-policy # smoke-test Keycloak-first OTP hooks
make pb-seed           # apply local-only fixture migrations to pb_data/

# Everything
devenv up              # start PocketBase + Elm dev server + Mailpit + Caddy + Keycloak
```

`devenv up` exposes the local stack through Caddy:

| URL | Service |
|---|---|
| `http://127.0.0.1:8080/` | Elm SPA |
| `http://127.0.0.1:8080/_/` | PocketBase admin UI |
| `http://127.0.0.1:8080/api/` | PocketBase REST API |
| `http://127.0.0.1:8080/mailpit/` | Mailpit email UI |
| `http://127.0.0.1:8080/auth/realms/competitions/` | Keycloak realm |

The `devenv` PocketBase process uses the repository-built `competition-pocketbase` binary, applies `pb_migrations/` first and then `pb_migrations_dev/` before serving. That gives local development an open competition, a finished gallery competition, demo local users, Keycloak shadow users, shared profiles, entries in draft/submitted/approved/rejected states, fixture images, reviews, and Mailpit SMTP settings.

Domain ownership must go through `profiles`. `entries.submitter` and `reviews.reviewer` relate to profiles, while `local_users` and `keycloak_users` are only authentication records. `pb_migrations_dev/` is local-only fixture data and must never be used for production.

---

## 8. TODO Execution Order

Work on TODOs in numerical order. Each TODO has its own acceptance criteria. Do not start a later TODO until all acceptance criteria of the previous TODO are met.

```
TODO-00 → TODO-01 → TODO-02 → TODO-03 → TODO-04 → TODO-05 → TODO-06 → TODO-07 → TODO-08
cleanup    schema     auth      submit    review    gallery   devenv    polish     fixes
```

> TODO-05 (gallery) and TODO-06 (devenv) can be worked on in parallel with TODO-03/04 if the PocketBase schema (TODO-01) is complete.
> TODO-07 must come before TODO-08 — it depends on all prior TODOs being complete.
> TODO-08 must come last — it addresses security, quality, and test gaps introduced in prior steps.
