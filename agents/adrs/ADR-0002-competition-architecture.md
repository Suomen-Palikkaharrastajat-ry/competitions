# ADR-0002: Competition Platform Architecture

**Status:** Accepted
**Date:** 2026-03-20

---

## Context

The repository was originally a "planet" RSS feed aggregator. It is being repurposed as a LEGO MOC competition platform for Suomen Palikkaharrastajat ry. We need to define the high-level architecture, component responsibilities, and integration points.

## Decision

The platform is split into three distinct components with clear boundaries:

### Component 1: PocketBase Backend

**Responsibilities:**
- Persistent storage for all domain data (competitions, entries, reviews, profiles)
- File storage for entry images and competition cover images
- Authentication (Keycloak OIDC or local OTP; no passwords)
- Access control (collection-level rules)
- REST API consumed by both the Elm app and the Haskell pipeline

**Why PocketBase** (see ADR-0001 for full rationale): single binary, zero external dependencies, SQLite-backed, built-in file storage, MIT licensed, OTP auth in ≥ 0.22.

**Auth strategy:** See ADR-0003. Email/password authentication is **disabled** for participant/reviewer auth collections. Keycloak OIDC wins over local OTP for matching emails.

### Component 2: Elm Single-Page Application (participant + reviewer UI)

**Responsibilities:**
- Keycloak OIDC login
- Local email/OTP login
- Browsing open competitions
- Submitting and editing draft entries (file upload, title, description)
- Viewing own submissions and their status
- Reviewer tools: scoring entries on 4 criteria, commenting, approving/rejecting
- Ranked voting during a competition's voting period, next to reviews (ADR-0007)

**Not responsible for:**
- The public gallery (that is the Haskell pipeline's output)
- Admin tasks (handled in PocketBase admin UI at `/_/`)

**Why Elm:** Type-safe UI, The Elm Architecture (TEA) for predictable state management, no runtime exceptions, excellent for form-heavy workflows. Already used in the prior project.

**Auth persistence:** PocketBase bearer token stored in `localStorage` via Elm ports. Token is re-validated on app load by making a lightweight API call.

### Component 3: Haskell Gallery Pipeline

**Responsibilities:**
- Reads approved entries and published reviews from PocketBase
- Generates a **self-contained static HTML gallery** (`dist/index.html`)
- Computes entry rankings based on aggregated review scores
- Runs as a CLI tool (`competition` executable) triggered manually or by CI

**Not responsible for:**
- Real-time updates (gallery is a build-time snapshot)
- Authentication or file upload

**Why Haskell:** Type safety for HTML generation (blaze-html), already present in the codebase, same GHC/cabal setup as before.

**Self-contained output:** The generated `dist/index.html` must include all CSS and JS inline (no external file dependencies except the Outfit font via Google Fonts CDN, which is an explicit allowed exception). This ensures the gallery can be served from any static host, including GitHub Pages.

---

## Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     PocketBase (backend)                    │
│  Collections: competitions, entries, reviews, profiles      │
│  Auth: users OIDC, local_users OTP                          │
│  Files: entry images, cover images                          │
│  Admin UI: /_/                                              │
└──────────────────────┬──────────────────────┬──────────────┘
                       │ REST API              │ REST API
                       │ (user token)          │ (API key)
                       ▼                       ▼
         ┌─────────────────────┐   ┌────────────────────────┐
         │ Elm SPA             │   │ Haskell Gallery        │
         │ (participant UI +   │   │ Pipeline               │
         │  reviewer tools)    │   │ → dist/index.html      │
         │ localhost:5173      │   │ (self-contained HTML)  │
         └─────────────────────┘   └────────────────────────┘
                  ↑                           ↑
           user browser                CI / manual run
```

---

## Architectural Constraints

1. **PocketBase is the single source of truth.** Neither the Elm app nor the Haskell pipeline maintain their own database state.

2. **The Elm app never calls the gallery pipeline** and vice versa. They are independent consumers of the PocketBase API.

3. **The gallery pipeline is read-only.** It only reads from PocketBase (GET requests). It never creates, updates, or deletes records.

4. **The Elm app uses user-scoped auth tokens.** The gallery pipeline uses a superuser API key (`POCKETBASE_API_KEY`). These must not be confused or swapped.

5. **PocketBase access rules are the security boundary.** The Elm app relies on PocketBase's `listRule`/`viewRule`/`createRule`/`updateRule`/`deleteRule` for authorization. The Haskell pipeline bypasses these rules (superuser key) and must not expose unpublished data.

6. **No password authentication.** Participant/reviewer auth collections must keep password auth disabled. `users` (the shared members, ADR-0006) uses OIDC; `local_users` uses OTP. Never introduce email+password auth without a new ADR.

7. **Images are served directly from PocketBase.** Do not proxy, re-upload, or cache images outside PocketBase in the Elm app. In the static gallery, images are linked via PocketBase file URLs (CDN in production).

8. **The gallery must not require login.** `dist/index.html` must be fully accessible without authentication. Only approved entries appear in the gallery.

9. **Migrations are the schema contract.** Never modify PocketBase collections via the Admin UI in a way not reflected in a `pb_migrations/` file. Schema is code.

10. **Brand design tokens are mandatory.** All UI (Elm app and generated gallery HTML) must use only named design tokens from the Suomen Palikkaharrastajat ry style guide. Raw hex values, pixel sizes, or font names must not appear in component code — use CSS variables or Tailwind token classes.

---

## Deployment Model (Production)

- PocketBase: single binary, runs on a VPS or managed server
- Elm app: built with `npm run build` → static files served by PocketBase's built-in static file serving, OR a CDN/static host
- Gallery: `dist/index.html` deployed to a static host (e.g., GitHub Pages, Netlify, PocketBase static dir)

The gallery can be regenerated after each competition concludes by running `make gallery-run` and redeploying `dist/`.

---

## Consequences

### Positive
- Clear separation of concerns: each component has a single job
- No shared code between Elm and Haskell (PocketBase API is the interface)
- Static gallery can be hosted cheaply and survives PocketBase downtime
- Keycloak-first auth lets organization-managed identities take precedence while preserving local OTP fallback
- PocketBase admin UI provides a no-code management interface for competitions

### Negative
- Gallery is not real-time: requires a pipeline run to reflect new approved entries
- Two codebases (Elm + Haskell) require separate toolchains
- PocketBase OTP requires SMTP configuration in production
