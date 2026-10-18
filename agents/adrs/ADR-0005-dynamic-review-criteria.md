# ADR-0005: Dynamic Review Criteria

**Status:** Accepted
**Date:** 2026-10-17

---

## Context

A review scored an entry on four fixed criteria, each a `score_*` number field
on the `reviews` collection, and the Elm app, the Haskell gallery and the labels
were written for those four. Competitions need other criteria, and later they
should choose their own. Labels must be translatable like the rest of the
app's text (ADR-0002, and the site configuration in
`vendor/master-builder/docs/site-config.md`).

## Decision

1. **The vocabulary lives in `config.toml`.** `[app] criteria` lists the
   criterion ids in display order. Each id's label is in `[app.strings]` as
   `criterion_<id>`, with the same key in every declared language. The build
   refuses a language that is missing a label. The four current criteria are
   the first value.

2. **A review stores one score per criterion.** The `reviews.scores` JSON field
   maps each criterion id to a whole number from 1 to 5 (migration 015 converts
   the old `score_*` fields). The Elm app, the gallery and the review total read
   the map, so a new criterion needs no schema change.

3. **The server checks the shape, not the vocabulary.** `pb_hooks/reviews.pb.js`
   accepts scores only as a non-empty object of whole numbers from 1 to 5 keyed
   by plain identifiers. The server does not read `config.toml`, so it cannot
   check that a criterion is configured. The Elm app builds every review from
   the configured criteria.

4. **The scale stays 1–5.** The Likert scale is not configurable yet.

## Consequences

- Adding a criterion means adding its id to `[app] criteria` and a label in
  each declared language. Until a label exists the Elm app reports the
  configuration as unreadable.
- A criterion id is stored in every review that scores it. Do not rename one
  that reviews use; retire it from `criteria` instead.
- The maximum score is 5 × the number of configured criteria. Scores of a
  criterion that is later removed still count in the stored review total.
- Choosing criteria per competition is not built yet. It needs a field on
  `competitions` and an admin form for it, and it will read the same vocabulary.
