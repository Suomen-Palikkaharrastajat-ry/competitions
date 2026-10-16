# US-005: Public Gallery

**As a visitor,** I want to browse a public gallery of approved MOC entries and see competition results, so that I can admire the builds without needing to log in.

## Acceptance Criteria

- [ ] Given the gallery pipeline has been run, when I open `dist/galleria/index.html`, then I see a list of competitions with their approved entries.
- [ ] Given a competition has `status = "finished"` and published reviews, when I view that competition's section, then I see a winner podium showing ranks 1–3 with scores.
- [ ] Given an entry has published reviews, when I view it in the gallery, then its average score is shown.
- [ ] Given a competition has no published reviews, when I view it in the gallery, then entries are shown without scores (no ranking).
- [ ] Given I view the gallery, then it loads correctly without any network requests other than the site's own Outfit font (`/fonts/outfit.css`) — it is self-contained.
- [ ] Given I click on an entry image, then a lightbox opens showing the full image.
- [ ] Given the gallery has more than one competition, then competitions are shown with the most recently finished first.
- [ ] Given `anonymize_submitters = true` in `competition.toml`, when the gallery is generated, then submitter names are not shown.

## Notes

- Gallery is a **build-time snapshot**: it does not update in real time.
- The gallery must pass basic WCAG AA accessibility (alt text on images, sufficient colour contrast).
- The gallery is published under the app's site at `/galleria/` and links the hub's self-hosted Outfit (`/fonts/outfit.css`) in `<head>` — its one dependency besides PocketBase image URLs.
