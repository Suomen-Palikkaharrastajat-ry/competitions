"""Project keywords the screencast engine has no primitive for.

Talks to the local devenv stack only (http://127.0.0.1:8080): resets its data
through the PocketBase API as the superuser from `.env`, completes the Keycloak
sign-in popup off camera, reads OTP codes from Mailpit, uploads files and
builds and serves the static gallery.
"""

import functools
import http.server
import json
import os
import re
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn

REPO = Path(__file__).resolve().parents[3]
BASE = "http://127.0.0.1:8080"
# The checkout to build the app and the gallery pipeline from (default: this
# one). Point it at a clean worktree when this checkout has unfinished changes.
APP_REPO = Path(os.environ.get("SCREENCAST_APP_REPO", REPO))


def _env():
    values = {}
    for line in (REPO / ".env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


@library(scope="GLOBAL")
class CompetitionsLibrary:
    def __init__(self):
        self._token = None
        self._gallery_server = None

    # -- PocketBase API ---------------------------------------------------

    def _request(self, method, path, body=None, files=None):
        headers = {"Authorization": self._superuser_token()}
        data = None
        if files:
            boundary = "----screencast%d" % time.time_ns()
            parts = []
            for name, value in (body or {}).items():
                parts.append(
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
                )
            for name, path_ in files:
                p = Path(path_)
                parts.append(
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{p.name}"\r\n'
                    f"Content-Type: image/png\r\n\r\n".encode()
                    + p.read_bytes()
                    + b"\r\n"
                )
            parts.append(f"--{boundary}--\r\n".encode())
            data = b"".join(parts)
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as err:
            raise AssertionError(f"{method} {path}: {err.code} {err.read().decode()}") from None
        return json.loads(raw) if raw else None

    def _superuser_token(self):
        if not self._token:
            env = _env()
            req = urllib.request.Request(
                BASE + "/api/collections/_superusers/auth-with-password",
                data=json.dumps(
                    {"identity": env["PB_SUPERUSER_EMAIL"], "password": env["PB_SUPERUSER_PASSWORD"]}
                ).encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req) as resp:
                self._token = json.load(resp)["token"]
        return self._token

    def _all(self, collection, filter_=None):
        query = {"perPage": "500"}
        if filter_:
            query["filter"] = filter_
        path = f"/api/collections/{collection}/records?" + urllib.parse.urlencode(query)
        return self._request("GET", path)["items"]

    @keyword
    def superuser_credentials(self):
        """The local superuser's email and password, for the Admin UI login."""
        env = _env()
        return env["PB_SUPERUSER_EMAIL"], env["PB_SUPERUSER_PASSWORD"]

    @keyword
    def reset_competition_data(self, otp_email, display_names):
        """Delete every competition, entry and review, remove the OTP user
        `otp_email`, and set the display names of the given profiles
        (`{email: name}`), so each take starts from the same state."""
        for collection in ("reviews", "entries", "competitions"):
            for record in self._all(collection):
                self._request("DELETE", f"/api/collections/{collection}/records/{record['id']}")
        quoted = json.dumps(otp_email)
        for collection in ("local_users", "profiles"):
            for record in self._all(collection, f"email = {quoted}"):
                self._request("DELETE", f"/api/collections/{collection}/records/{record['id']}")
        for email, name in display_names.items():
            quoted = json.dumps(email)
            for collection in ("profiles", "users", "local_users"):
                for record in self._all(collection, f"email = {quoted}"):
                    self._request(
                        "PATCH",
                        f"/api/collections/{collection}/records/{record['id']}",
                        {"display_name": name},
                    )
        self._delete_mail()

    @keyword
    def create_submitted_entry(self, competition_title, submitter_email, title, description, *images):
        """Create an already submitted entry for `submitter_email` (a profile)."""
        competition = self._all("competitions", f"title = {json.dumps(competition_title)}")[0]
        profile = self._all("profiles", f"email = {json.dumps(submitter_email)}")[0]
        fields = {
            "competition": competition["id"],
            "submitter": profile["id"],
            "title": title,
            "description": description,
            "status": "submitted",
            "submitted_at": time.strftime("%Y-%m-%d %H:%M:%S.000Z", time.gmtime()),
        }
        self._request(
            "POST", "/api/collections/entries/records", fields, files=[("images", p) for p in images]
        )

    @keyword
    def approve_entry(self, title):
        """Set the status of an entry to 'approved'."""
        for record in self._all("entries", f"title = {json.dumps(title)}"):
            self._request("PATCH", f"/api/collections/entries/records/{record['id']}", {"status": "approved"})

    @keyword
    def create_published_review(
        self, entry_title, reviewer_email, theme=5, originality=5, technique=5, presentation=5, comment=""
    ):
        """Create a published review for an entry as reviewer_email."""
        entry = self._all("entries", f"title = {json.dumps(entry_title)}")[0]
        reviewer = self._all("profiles", f"email = {json.dumps(reviewer_email)}")[0]
        fields = {
            "entry": entry["id"],
            "reviewer": reviewer["id"],
            "scores": {
                "theme": int(theme),
                "originality": int(originality),
                "technique": int(technique),
                "presentation": int(presentation),
            },
            "comment": comment,
            "is_published": True,
        }
        self._request("POST", "/api/collections/reviews/records", fields)

    # -- Browser helpers --------------------------------------------------

    def _page(self):
        return BuiltIn().get_library_instance("screencast.Screencast").get_current_page()

    @keyword
    def sign_in_with_keycloak(self, username, password):
        """Click the Keycloak button on camera and complete the sign-in
        popup off camera (the engine records only the main page)."""
        page = self._page()
        with page.context.expect_page() as popup_info:
            BuiltIn().run_keyword("Human Click", 'role=button[name="Kirjaudu Keycloakilla"]')
        popup = popup_info.value
        popup.wait_for_load_state()
        popup.fill("#username", username)
        popup.fill("#password", password)
        popup.click("#kc-login")
        popup.wait_for_event("close", timeout=20000)

    @keyword
    def admin_session(self):
        """localStorage entries that sign the PocketBase Admin UI in as the
        local superuser, for `Use Session` or a Playwright storage state."""
        env = _env()
        req = urllib.request.Request(
            BASE + "/api/collections/_superusers/auth-with-password",
            data=json.dumps(
                {"identity": env["PB_SUPERUSER_EMAIL"], "password": env["PB_SUPERUSER_PASSWORD"]}
            ).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req) as resp:
            auth = json.load(resp)
        value = json.dumps({"token": auth["token"], "record": auth["record"]})
        return {"__pb_superusers__/_": value}

    @keyword
    def admin_storage_state(self):
        """A Playwright storage state for `Start Observer` (Admin UI)."""
        items = [{"name": k, "value": v} for k, v in self.admin_session().items()]
        return {"cookies": [], "origins": [{"origin": BASE, "localStorage": items}]}

    @keyword
    def app_session(self):
        """The current page's competitions app session (`pb_auth`)."""
        return {"pb_auth": self._page().evaluate("localStorage.getItem('pb_auth')")}

    @keyword
    def use_session(self, items, origin=BASE):
        """Put `items` into localStorage of `origin` in the current turn's
        context before any page script runs, so the next `Go To` there
        starts signed in."""
        script = "".join(
            f"localStorage.setItem({json.dumps(k)}, {json.dumps(v)});" for k, v in items.items()
        )
        self._page().context.add_init_script(
            f"if (location.origin === {json.dumps(origin)}) {{ {script} }}"
        )

    @keyword
    def fill_field(self, selector, value):
        """Set a field's value at once (date inputs, which typing cannot)."""
        lib = BuiltIn().get_library_instance("screencast.Screencast")
        locator = lib._locator(selector) if hasattr(lib, "_locator") else self._page().locator(selector)
        locator.fill(value)

    @keyword
    def refresh_admin_list(self):
        """Click the Admin UI's Refresh button on the observer page."""
        lib = BuiltIn().get_library_instance("screencast.Screencast")
        lib.get_observer_page().get_by_role("button", name="Refresh").click()

    @keyword
    def save_draft(self):
        """Click "Tallenna luonnos" and wait until PocketBase has stored the
        draft (the app shows no confirmation of its own)."""
        page = self._page()
        with page.expect_response(
            lambda r: "/api/collections/entries/records" in r.url and r.request.method in ("POST", "PATCH"),
            timeout=15000,
        ) as response:
            BuiltIn().run_keyword("Human Click", 'role=button[name="Tallenna luonnos"]')
        if not response.value.ok:
            raise AssertionError(f"Saving the draft failed: {response.value.status}")

    @keyword
    def upload_images(self, selector, *paths):
        """Put `paths` into the file input `selector` of the current page."""
        self._page().set_input_files(selector, [str(Path(p).resolve()) for p in paths])

    # -- Mailpit ------------------------------------------------------------

    def _delete_mail(self):
        req = urllib.request.Request(BASE + "/mailpit/api/v1/messages", method="DELETE")
        urllib.request.urlopen(req).read()

    @keyword
    def latest_login_code(self, email, timeout=20):
        """The 6-digit code in the newest Mailpit message to `email`."""
        deadline = time.time() + float(timeout)
        query = urllib.parse.quote(f"to:{email}")
        while time.time() < deadline:
            found = json.load(urllib.request.urlopen(f"{BASE}/mailpit/api/v1/search?query={query}"))
            if found.get("messages"):
                message_id = found["messages"][0]["ID"]
                text = json.load(urllib.request.urlopen(f"{BASE}/mailpit/api/v1/message/{message_id}"))["Text"]
                match = re.search(r"\b(\d{6})\b", text)
                if match:
                    return match.group(1)
            time.sleep(0.5)
        raise AssertionError(f"No login code for {email} in Mailpit")

    # -- Gallery ------------------------------------------------------------

    @keyword
    def prepare_gallery_builder(self):
        """Resolve the Nix-built gallery pipeline once (evaluating the devenv
        shell takes a minute), so `Build Gallery` itself is quick."""
        result = subprocess.run(
            ["devenv", "--profile", "ci", "shell", "--no-eval-cache", "--", "bash", "-c", 'echo "$COMPETITION_NIX"'],
            cwd=APP_REPO,
            check=True,
            capture_output=True,
            text=True,
        )
        self._gallery_builder = result.stdout.strip().splitlines()[-1]
        return self._gallery_builder

    @keyword
    def build_gallery(self, builder=None):
        """Run the gallery pipeline against the local PocketBase."""
        builder = builder or getattr(self, "_gallery_builder", None) or self.prepare_gallery_builder()
        # A fresh superuser token: the API key in .env may be from another database.
        env = {**os.environ, **_env(), "POCKETBASE_URL": BASE, "POCKETBASE_API_KEY": self._superuser_token()}
        # Writes dist/galleria/ (competition.toml) next to the served app.
        subprocess.run([builder], cwd=APP_REPO, env=env, check=True, capture_output=True)

    def _serve(self, name, directory, port):
        servers = self.__dict__.setdefault("_servers", {})
        if name not in servers:

            class Quiet(http.server.SimpleHTTPRequestHandler):
                def log_message(self, *args):
                    pass

            handler = functools.partial(Quiet, directory=str(directory))
            server = http.server.ThreadingHTTPServer(("127.0.0.1", int(port)), handler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            servers[name] = server
        return f"http://127.0.0.1:{servers[name].server_address[1]}"

    @keyword
    def serve_gallery(self):
        """The gallery's URL: dist/galleria/ under the served app, as in
        production (it uses the app's /fonts/)."""
        return self.serve_app_build() + "/galleria/"

    @keyword
    def build_app(self):
        """Production build of the app (no dev-server overlays on camera)."""
        subprocess.run(
            ["devenv", "--profile", "shell", "shell", "--no-eval-cache", "--", "make", "elm-build"],
            cwd=APP_REPO,
            check=True,
            capture_output=True,
        )

    @keyword
    def serve_app_build(self, port=5174):
        """Serve the production build (dist/) and return its origin."""
        return self._serve("app", APP_REPO / "dist", port)
