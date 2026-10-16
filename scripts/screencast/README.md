# Organiser screencast

`kilpailun-jarjestaminen.robot` records a Finnish how-to video for competition
organisers: Olli creates a competition in the PocketBase Admin UI, Aino (member,
Keycloak) and Ville (email code) submit entries, Olli moves the competition to
judging, scores, approves and rejects entries, Aino sees her score, and the
finished competition appears in the public gallery.

It is a [robotframework-screencast](https://github.com/datakurre/robotframework-screencast)
story: `resources/competitions.resource` holds the app's keywords,
`resources/CompetitionsLibrary.py` what the engine has no primitive for (API
reset, the Keycloak popup, Mailpit codes, uploads, the gallery build) and
`images/` the placeholder photos.

## Running

Local stack only — the first task **deletes every competition, entry and
review** in the PocketBase it talks to.

```sh
devenv up                                   # in another terminal
cd scripts/screencast
TAKE=/tmp/kilpailu-take
nix run github:datakurre/robotframework-screencast -- run kilpailun-jarjestaminen.robot --take $TAKE
nix run github:datakurre/robotframework-screencast -- compose $TAKE
nix run github:datakurre/robotframework-screencast -- verify $TAKE   # report.json, contact-sheet.png
cp $TAKE/output.webm $TAKE/output.vtt .     # the video and its captions
```

Add `--no-record` to `run` while changing the story; it checks every step
without writing video.

The story builds the app for production and serves it on
`http://127.0.0.1:5174` (no dev-server overlays on camera); PocketBase, its
Admin UI and Mailpit stay on `http://127.0.0.1:8080`. It builds the app and
the gallery pipeline from this checkout, or from `SCREENCAST_APP_REPO` (for
example a clean `git worktree`) when this one has unfinished changes.

Environment notes:

- If Chromium fails with a glibc version error, point the engine at a
  Playwright browser build that matches your system:
  `PLAYWRIGHT_BROWSERS_PATH=… screencast run …`.
- If `compose`/`verify` fail in `ffprobe` while it works on its own, a global
  `LD_LIBRARY_PATH` is loading foreign libraries: run them with
  `env -u LD_LIBRARY_PATH`.
