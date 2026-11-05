"""Render the Argo CD apps of this repo the way Argo CD does, for the doc generators.

Shared by netflow.py (network policies) and authflow.py (authentication):
walk the app of apps (2.argo/app) and, recursively, every Application it
produces that points back into this repo, with the valuesObject it carries.
Disabled apps are simply never rendered, as in the cluster.

Only stdlib: YAML goes through `yq -o=json`, so the pre-commit hook needs
nothing beyond helm and yq, both pinned in mise.toml.
"""
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_CHART = "2.argo/app"
# Stands in for the git URL the app of apps is given: an Application whose
# repoURL is this one points back into the checkout, anything else (upstream
# charts) is not ours to render.
REPO = "https://netflow.invalid/weebo-si.git"


def run(*cmd, cwd=None, stdin=None):
    return subprocess.run(cmd, cwd=cwd, input=stdin, capture_output=True, text=True)


def yaml_docs(text):
    res = run("yq", "-o=json", "-I=0", ".", "-", stdin=text)
    if res.returncode != 0:
        raise RuntimeError(res.stderr)
    return [json.loads(l) for l in res.stdout.splitlines() if l.strip() not in ("", "null")]


def render(chart, release, namespace, values, sets=()):
    """helm template with the valuesObject the parent Application passes,
    plus `--set` overrides. Returns (docs, None) or (None, first error)."""
    args = ["helm", "template", release, ".", "--namespace", namespace, "--values", "-"]
    for s in sets:
        args += ["--set", s]
    res = run(*args, cwd=ROOT / chart, stdin=json.dumps(values))
    if res.returncode != 0:
        err = [l for l in res.stderr.splitlines() if l.startswith("Error")]
        return None, (err or ["helm template failed"])[0]
    return yaml_docs(res.stdout), None


@dataclass
class Render:
    chart: str
    namespace: str
    app: str  # the Argo CD app of the 2.argo/app level it descends from, None for the app of apps itself
    live: list  # None when helm template failed
    err: str = None
    forced: list = None  # the render with forced_sets added, if asked


def walk(sets=(), forced_sets=None):
    """Yield one Render per chart, breadth first from the app of apps.
    With forced_sets, each chart that renders is rendered a second time with
    those `--set` added (netflow: what a disabled weebo-base would add)."""
    queue = [(APP_CHART, "app", "argocd", {"repo": REPO, "branch": "develop"}, None)]
    seen = set()
    while queue:
        chart, release, namespace, values, app = queue.pop(0)
        if chart in seen:
            continue
        seen.add(chart)
        run("helm", "dependency", "build", "--skip-refresh", cwd=ROOT / chart)
        live, err = render(chart, release, namespace, values, sets)
        if live is None:
            yield Render(chart, namespace, app, None, err)
            continue
        forced = None
        if forced_sets is not None:
            forced, _ = render(chart, release, namespace, values, (*sets, *forced_sets))
        for d in live:
            src = (d.get("spec") or {}).get("source") or {}
            path = (src.get("path") or "").rstrip("/")
            if d.get("kind") != "Application" or src.get("repoURL") != REPO or not (ROOT / path / "Chart.yaml").exists():
                continue
            helm = src.get("helm") or {}
            child_values = helm.get("valuesObject") or (yaml_docs(helm["values"])[0] if helm.get("values") else {})
            queue.append((path, helm.get("releaseName") or d["metadata"]["name"],
                          d["spec"]["destination"].get("namespace", "default"), child_values,
                          app or d["metadata"]["name"]))
        yield Render(chart, namespace, app, live, None, forced)
