#!/usr/bin/env python3
"""Reconcile HyperDX dashboards against the JSON files committed to this repo.

HyperDX has no provisioning hook for dashboards. setupDefaults.ts only reads
DEFAULT_CONNECTIONS / DEFAULT_SOURCES, and the `provisioned` flag on the
Dashboard model is written by ClickHouse Cloud's control plane, never by
anything reachable in the OSS image. The dashboard CRUD routes sit behind
session auth (`app.use('/dashboards', isUserAuthenticated, ...)`), so the only
supported way in is to log in as the bootstrap admin and drive exactly the
endpoints the UI drives.

Ownership is tracked with a tag (MANAGED_TAG). A dashboard carrying it belongs
to this repo and gets updated -- or pruned once its file is deleted from git.
Dashboards built by hand in the UI never carry the tag, so they are never
touched unless their name is listed explicitly in DELETE_NAMES.

Stdlib only, on purpose: the Job runs on a stock python image with no network
access to a package index.
"""

import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

API_URL = os.environ["API_URL"].rstrip("/")
ADMIN_EMAIL = os.environ["ADMIN_EMAIL"]
ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]
MANAGED_TAG = os.environ["MANAGED_TAG"]
DASHBOARD_DIR = pathlib.Path(os.environ.get("DASHBOARD_DIR", "/dashboards"))
PRUNE = os.environ.get("PRUNE", "true").lower() == "true"
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
DELETE_NAMES = json.loads(os.environ.get("DELETE_NAMES") or "[]")

# Bookkeeping that comes back on GET but must not be sent back in: mongoose
# internals, the populated `alerts` array (alerts are derived from tile config,
# not settable here), and `provisioned` (rejects UI edits -- setting it by hand
# would make the dashboard read-only for humans).
SERVER_OWNED_KEYS = frozenset(
    {
        "_id",
        "id",
        "__v",
        "team",
        "alerts",
        "provisioned",
        "createdAt",
        "createdBy",
        "updatedAt",
        "updatedBy",
    }
)


OBJECT_ID = re.compile(r"^[0-9a-f]{24}$")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Login answers 303 -> FRONTEND_URL, the public Ingress host. Following it
    from inside the cluster lands on Authentik rather than the API, so the
    redirect is swallowed and the 3xx treated as the success it is."""

    def redirect_request(self, *_args, **_kwargs):
        return None


_opener = urllib.request.build_opener(_NoRedirect)
# Set by login(). Not an http.cookiejar: api-app.ts scopes the session cookie to
# FRONTEND_URL's hostname (clickstack.weebo.poc), which a jar would refuse to
# send back to the in-cluster Service host. Replaying the header verbatim
# sidesteps domain matching entirely.
_cookie = None


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(API_URL + path, data=data, method=method)
    # api-app.ts sets `app.set('trust proxy', 1)` and, because FRONTEND_URL is
    # https, `cookie.secure = true`. express-session then refuses to emit
    # Set-Cookie at all unless the request looks like it arrived over TLS --
    # which, on plain http://clickstack:8000, only this header establishes.
    request.add_header("X-Forwarded-Proto", "https")
    if _cookie is not None:
        request.add_header("Cookie", _cookie)
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with _opener.open(request, timeout=30) as response:
            return response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        return error.code, error.read(), error.headers


def fail(message, status=None, payload=None):
    suffix = f" (HTTP {status})" if status else ""
    print(f"error: {message}{suffix}", file=sys.stderr)
    if payload:
        print(payload.decode("utf-8", "replace")[:2000], file=sys.stderr)
    sys.exit(1)


def wait_for_api(attempts=120, delay=5):
    print(f"waiting for the HyperDX API on {API_URL}")
    for _ in range(attempts):
        try:
            if call("GET", "/health")[0] == 200:
                return
        except OSError:
            pass
        time.sleep(delay)
    fail(f"API never became ready ({attempts * delay // 60} min)")


def login():
    global _cookie
    status, payload, headers = call(
        "POST",
        "/login/password",
        {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    # passport is configured with failWithError, so a bad password is a 401;
    # success is redirectToDashboard's 303 (302 accepted in case that changes).
    if status not in (200, 302, 303):
        fail("login as the bootstrap admin failed", status, payload)
    raw = headers.get("Set-Cookie")
    if not raw:
        fail(
            "login succeeded but set no session cookie -- FRONTEND_URL is https "
            "and X-Forwarded-Proto did not take effect",
            status,
        )
    _cookie = raw.split(";", 1)[0]


def dashboard_id(dashboard):
    value = dashboard.get("id") or dashboard.get("_id")
    return value.get("$oid") if isinstance(value, dict) else value


def get_json(path, what):
    status, payload, _ = call("GET", path)
    if status != 200:
        fail(f"could not list {what}", status, payload)
    body = json.loads(payload or b"[]")
    if isinstance(body, dict):
        body = body.get("data") or body.get(what) or []
    return body


def build_reference_map():
    """Maps source/connection NAMES to the ObjectIds a tile config must carry.

    Both are created by setupTeamDefaults() at registration, so their ids differ
    per install and can never be committed. Dashboard files therefore name them
    ("Metrics", "Local ClickHouse") and the id is substituted here.
    """
    names = {}
    for source in get_json("/sources", "sources"):
        names[source["name"]] = dashboard_id(source)
    for connection in get_json("/connections", "connections"):
        names[connection["name"]] = dashboard_id(connection)
    return names


def resolve_references(node, names, where):
    """Rewrites every source/connection reference in place, depth first."""
    if isinstance(node, list):
        for item in node:
            resolve_references(item, names, where)
        return
    if not isinstance(node, dict):
        return
    for key, value in node.items():
        if key in ("source", "connection", "sourceId") and isinstance(value, str):
            node[key] = resolve_one(value, names, where)
        elif key == "appliesToSourceIds" and isinstance(value, list):
            node[key] = [resolve_one(v, names, where) for v in value]
        else:
            resolve_references(value, names, where)


def resolve_one(value, names, where):
    if value in names:
        return names[value]
    # Already an id (or a hand-pasted one) -- left alone so an unedited export
    # round-trips on the install it came from.
    if OBJECT_ID.match(value):
        return value
    fail(
        f"{where} references {value!r}, which is neither an ObjectId nor a known "
        f"source/connection name. Known names: {sorted(names)}"
    )


def load_desired():
    """name -> (source file, payload), with MANAGED_TAG forced onto every one."""
    desired = {}
    for path in sorted(DASHBOARD_DIR.glob("*.json")):
        try:
            document = json.loads(path.read_text())
        except json.JSONDecodeError as error:
            fail(f"{path.name} is not valid JSON: {error}")
        name = document.get("name")
        if not name:
            fail(f"{path.name} has no .name")
        if name in desired:
            fail(f"{path.name} and {desired[name][0]} both define {name!r}")
        payload = {k: v for k, v in document.items() if k not in SERVER_OWNED_KEYS}
        # DashboardWithoutIdSchema requires both, and an exported dashboard with
        # no tiles yet legitimately omits the empty array.
        payload.setdefault("tiles", [])
        payload["tags"] = [t for t in payload.get("tags", []) if t != MANAGED_TAG]
        payload["tags"].append(MANAGED_TAG)
        desired[name] = (path.name, payload)
    return desired


def act(description, method, path, body=None):
    if DRY_RUN:
        print(f"dry-run: would {description}")
        return
    status, payload, _ = call(method, path, body)
    if status not in (200, 201, 204):
        fail(f"failed to {description}", status, payload)
    print(description)


def main():
    wait_for_api()
    login()

    desired = load_desired()
    clashes = sorted(set(DELETE_NAMES) & set(desired))
    if clashes:
        fail(f"listed in dashboards.delete but also defined by a file: {clashes}")

    names = build_reference_map()
    for name, (source, payload) in desired.items():
        resolve_references(payload, names, source)

    # Names are only unique among provisioned dashboards upstream, so group
    # rather than assuming one document per name.
    managed, unmanaged = {}, {}
    for dashboard in get_json("/dashboards", "dashboards"):
        bucket = managed if MANAGED_TAG in (dashboard.get("tags") or []) else unmanaged
        bucket.setdefault(dashboard.get("name"), []).append(dashboard)

    print(
        f"{len(desired)} dashboard(s) in git, "
        f"{sum(map(len, managed.values()))} managed / "
        f"{sum(map(len, unmanaged.values()))} hand-made in the instance"
    )

    for name, (source, payload) in desired.items():
        current = managed.get(name, [])
        if not current:
            if name in unmanaged:
                print(
                    f"warn: a hand-made dashboard is also named {name!r}; "
                    f"creating a second, managed one from {source}"
                )
            act(f"create {name!r} from {source}", "POST", "/dashboards", payload)
            continue
        act(
            f"update {name!r} from {source}",
            "PATCH",
            f"/dashboards/{dashboard_id(current[0])}",
            payload,
        )
        # Only reachable if someone duplicated a managed dashboard in the UI.
        for duplicate in current[1:]:
            act(
                f"drop duplicate of {name!r}",
                "DELETE",
                f"/dashboards/{dashboard_id(duplicate)}",
            )

    # Deleting a dashboard cascades to the alerts its tiles declared
    # (deleteDashboardAlerts), so no orphans are left behind.
    if PRUNE:
        for name, duplicates in managed.items():
            if name in desired:
                continue
            for dashboard in duplicates:
                act(
                    f"prune {name!r} (no longer in git)",
                    "DELETE",
                    f"/dashboards/{dashboard_id(dashboard)}",
                )

    for name in DELETE_NAMES:
        targets = managed.get(name, []) + unmanaged.get(name, [])
        if not targets:
            print(f"delete: nothing named {name!r}, already gone")
        for dashboard in targets:
            act(
                f"delete {name!r} (dashboards.delete)",
                "DELETE",
                f"/dashboards/{dashboard_id(dashboard)}",
            )

    print("dashboards reconciled")


if __name__ == "__main__":
    main()
