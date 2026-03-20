# US-006: Configure Gallery via TOML

**As an administrator,** I want to configure the gallery pipeline via a `competition.toml` file so that I can set the site title, locale, timezone, and output directory without editing code.

## Acceptance Criteria

- [ ] Given a valid `competition.toml` with `title = "My Club Kilpailu"`, when the gallery pipeline runs, then the generated HTML `<title>` contains "My Club Kilpailu".
- [ ] Given `locale = "fi"` in the config, when the gallery is generated, then dates are formatted in Finnish (e.g., "15. tammikuuta 2026").
- [ ] Given `locale = "en"`, when the gallery is generated, then dates are formatted in English.
- [ ] Given `timezone = "Europe/Helsinki"`, when dates are displayed, then they are adjusted to that timezone.
- [ ] Given `output_dir = "public"`, when the pipeline runs, then the output is written to `public/index.html` instead of `dist/index.html`.
- [ ] Given `anonymize_submitters = true`, when the gallery is generated, then submitter names are replaced with "Osallistuja" or omitted.
- [ ] Given the `competition.toml` file is missing, when the pipeline runs, then it fails with a clear error message.
- [ ] Given `competition.toml` has an unknown key, when the pipeline runs, then it logs a warning but does not crash.

## Notes

- `POCKETBASE_URL` and `POCKETBASE_API_KEY` remain environment-variable-only (not in TOML).
- Defaults: `title = "Kilpailu"`, `locale = "fi"`, `timezone = "Europe/Helsinki"`, `output_dir = "dist"`, `anonymize_submitters = false`.
