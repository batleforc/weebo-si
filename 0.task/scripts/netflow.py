#!/usr/bin/env python3
"""Draw the network policies of the Argo CD apps as Mermaid, into the docs.

Renders the app of apps (2.argo/app) and, recursively, every Application it
produces that points back into this repo, with the valuesObject it carries --
what Argo CD itself does. Keeps the CiliumNetworkPolicy and NetworkPolicy
documents and writes one global diagram plus one per Argo CD app under
0.docs/content/docs/security/network-flows/.

Each chart is rendered twice: with its values as they are (what Argo CD
deploys today) and with ciliumNetworkPolicies.enabled forced on (what
2.helm/weebo-base would add). A flow only present in the second render is a
proposal and is drawn dashed.

Only stdlib: YAML goes through `yq -o=json`, so the pre-commit hook needs
nothing beyond helm and yq, both pinned in mise.toml.

    task docs:netflow
"""
import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "0.docs/content/docs/security/network-flows"
APP_CHART = "2.argo/app"
# Stands in for the git URL the app of apps is given: an Application whose
# repoURL is this one points back into the checkout, anything else (upstream
# charts) is not ours to render.
REPO = "https://netflow.invalid/weebo-si.git"
NS_KEY = "io.kubernetes.pod.namespace"
NS_LABEL = "io.cilium.k8s.namespace.labels."
WORKSPACES = "workspaces Che (dev-ws-*)"
# Namespace-label selectors that stand for a known set of namespaces.
NS_ALIASES = {"app.kubernetes.io/component=workspaces-namespace": WORKSPACES}
# The network profiles of che/hardening: never selected where they live, the
# operator copies them into each workspace namespace with its own selector.
TEMPLATE_LABEL = "hardening.weebo.io/never-selected"
GENERATED = "{/* Généré par `task docs:netflow` (0.task/scripts/netflow.py). Ne pas éditer à la main. */}"


def run(*cmd, cwd=None, stdin=None):
    return subprocess.run(cmd, cwd=cwd, input=stdin, capture_output=True, text=True)


def yaml_docs(text):
    res = run("yq", "-o=json", "-I=0", ".", "-", stdin=text)
    if res.returncode != 0:
        raise RuntimeError(res.stderr)
    return [json.loads(l) for l in res.stdout.splitlines() if l.strip() not in ("", "null")]


# ── Rendering, the way Argo CD does it ───────────────────────────────────────


def render(chart, release, namespace, values, force=False):
    """helm template with the valuesObject the parent Application passes."""
    # netflowRender: weebo-base then also emits the docs-only NetflowReaches.
    args = ["helm", "template", release, ".", "--namespace", namespace, "--values", "-",
            "--set", "netflowRender=true"]
    if force:
        args += ["--set", "ciliumNetworkPolicies.enabled=true"]
    res = run(*args, cwd=ROOT / chart, stdin=json.dumps(values))
    if res.returncode != 0:
        err = [l for l in res.stderr.splitlines() if l.startswith("Error")]
        return None, (err or ["helm template failed"])[0]
    return yaml_docs(res.stdout), None


def policies():
    """Walk the app of apps: 2.argo/app, then every Application rendered from
    it that points back into this repo, with the valuesObject it carries.
    Disabled apps are simply never rendered, as in the cluster."""
    queue = [(APP_CHART, "app", "argocd", {"repo": REPO, "branch": "develop"}, None)]
    out, skipped, seen, routes, upstream, reaches = [], [], set(), [], [], []
    while queue:
        chart, release, namespace, values, app = queue.pop(0)
        if chart in seen:
            continue
        seen.add(chart)
        run("helm", "dependency", "build", "--skip-refresh", cwd=ROOT / chart)
        live, err = render(chart, release, namespace, values)
        if live is None:
            skipped.append((chart, app or "app of apps", err))
            continue
        forced, _ = render(chart, release, namespace, values, force=True)
        for d in live:
            src = (d.get("spec") or {}).get("source") or {}
            path = (src.get("path") or "").rstrip("/")
            if d.get("kind") == "Application" and src.get("chart"):
                upstream.append(d)
            if d.get("kind") != "Application" or src.get("repoURL") != REPO or not (ROOT / path / "Chart.yaml").exists():
                continue
            helm = src.get("helm") or {}
            child_values = helm.get("valuesObject") or (yaml_docs(helm["values"])[0] if helm.get("values") else {})
            queue.append((path, helm.get("releaseName") or d["metadata"]["name"],
                          d["spec"]["destination"].get("namespace", "default"), child_values,
                          app or d["metadata"]["name"]))
        routes += [(d, namespace) for d in live if d.get("kind") in ("IngressRoute", "Ingress")]
        reaches += [(e, app or "app of apps") for d in live if d.get("kind") == "NetflowReaches"
                    for e in d.get("entries") or []]
        kinds = ("CiliumNetworkPolicy", "NetworkPolicy")
        live_ids = {(d["kind"], d["metadata"].get("namespace") or namespace, d["metadata"]["name"])
                    for d in live if d.get("kind") in kinds}
        for d in (forced or live):
            if d.get("kind") not in kinds:
                continue
            ns = d["metadata"].get("namespace") or namespace
            out.append({"app": app, "chart": chart, "ns": ns, "doc": d,
                        "active": (d["kind"], ns, d["metadata"]["name"]) in live_ids})
    return out, skipped, routes, upstream, reaches


# ── Policy -> edges ──────────────────────────────────────────────────────────


def strip(k):
    return k[4:] if k.startswith("k8s:") else k


def selector_name(sel):
    """Short, stable label for a pod selector (namespace keys excluded)."""
    ml = {strip(k): v for k, v in (sel.get("matchLabels") or {}).items()
          if strip(k) != NS_KEY and not strip(k).startswith(NS_LABEL)}
    parts = []
    for key in ("app.kubernetes.io/name", "app", "k8s-app", "vault_cr", "longhorn.io/component",
                "longhorn.io/admission-webhook", "longhorn.io/recovery-backend"):
        if key in ml:
            parts.append(ml.pop(key))
            break
    if "app.kubernetes.io/component" in ml:
        parts.append(ml.pop("app.kubernetes.io/component"))
    ml.pop("app.kubernetes.io/instance", None)
    parts += [f"{k}={v}" for k, v in sorted(ml.items()) if k != "hardening.weebo.io/never-selected"]
    for e in sel.get("matchExpressions") or []:
        parts.append(f"{strip(e['key']).split('/')[-1]} {e['operator']} {','.join(e.get('values') or [])}")
    return " / ".join(parts) or "tous les pods"


def cilium_peer(sel, policy_ns):
    """(namespace or pseudo-namespace, pod label) of a Cilium endpoint selector."""
    ml = {strip(k): v for k, v in (sel.get("matchLabels") or {}).items()}
    ns_labels = {k[len(NS_LABEL):]: v for k, v in ml.items() if k.startswith(NS_LABEL)}
    if NS_KEY in ml:
        ns = ml[NS_KEY] or "(hors namespace)"
    elif ns_labels:
        key = ",".join(f"{k}={v}" for k, v in sorted(ns_labels.items()))
        ns = NS_ALIASES.get(key, "namespaces " + key)
    else:
        ns = policy_ns
    return ("ns", ns, selector_name(sel))


def ports_of(rule, key="toPorts"):
    out = []
    for tp in rule.get(key) or []:
        l7 = " (dns)" if (tp.get("rules") or {}).get("dns") else ""
        for p in tp.get("ports") or []:
            proto = p.get("protocol", "TCP")
            out.append(f"{proto} {p['port']}{l7}")
    return out


def cilium_edges(p):
    doc, ns = p["doc"], p["ns"]
    spec = doc.get("spec") or {}
    sel = spec.get("endpointSelector") or {}
    me = ("ns", ns, selector_name(sel))
    if TEMPLATE_LABEL in {strip(k) for k in sel.get("matchLabels") or {}}:
        ns = WORKSPACES
        me = ("ns", ns, "profil " + doc["metadata"]["name"])
    edges = []
    for rule in spec.get("ingress") or []:
        ports = ports_of(rule)
        ents = rule.get("fromEntities") or []
        # host/remote-node without ports is the floor every weebo-base policy
        # carries (kubelet probes, apiserver -> webhooks): noise on a diagram.
        if ents and not ports and set(ents) <= {"host", "remote-node"}:
            ents = []
        peers = [("entity", e, e) for e in ents]
        peers += [cilium_peer(s, ns) for s in rule.get("fromEndpoints") or []]
        peers += [("cidr", c, c) for c in rule.get("fromCIDR") or []]
        peers += [("cidr", c["cidr"], c["cidr"]) for c in rule.get("fromCIDRSet") or []]
        edges += [(peer, me, ports) for peer in peers]
    for rule in spec.get("egress") or []:
        ports = ports_of(rule)
        peers = [("entity", e, e) for e in rule.get("toEntities") or []]
        peers += [cilium_peer(s, ns) for s in rule.get("toEndpoints") or []]
        peers += [("cidr", c, c) for c in rule.get("toCIDR") or []]
        peers += [("cidr", c["cidr"], c["cidr"]) for c in rule.get("toCIDRSet") or []]
        # One box per rule: an upstream and its CDNs read as one destination.
        fqdns = [f.get("matchName") or f.get("matchPattern") for f in rule.get("toFQDNs") or []]
        if fqdns:
            peers.append(("fqdn", ",".join(fqdns), "<br/>".join(fqdns)))
        edges += [(me, peer, ports) for peer in peers]
    return edges


def k8s_edges(p):
    doc, ns = p["doc"], p["ns"]
    spec = doc.get("spec") or {}
    me = ("ns", ns, selector_name(spec.get("podSelector") or {}))
    edges = []

    def peers_of(entries):
        if not entries:
            return [("entity", "all", "partout")]
        out = []
        for e in entries:
            if "ipBlock" in e:
                out.append(("cidr", e["ipBlock"]["cidr"], e["ipBlock"]["cidr"]))
                continue
            nsel = e.get("namespaceSelector")
            psel = e.get("podSelector") or {}
            if nsel is None:
                peer_ns = ns
            elif not nsel.get("matchLabels") and not nsel.get("matchExpressions"):
                peer_ns = "tous les namespaces"
            else:
                ml = nsel.get("matchLabels") or {}
                peer_ns = ml.get("kubernetes.io/metadata.name") or "namespaces " + ",".join(
                    f"{k}={v}" for k, v in sorted(ml.items()))
            out.append(("ns", peer_ns, selector_name(psel)))
        return out

    def ports(rule):
        return [f"{x.get('protocol', 'TCP')} {x.get('port', 'tous')}" for x in rule.get("ports") or []]

    for rule in spec.get("ingress") or []:
        edges += [(peer, me, ports(rule)) for peer in peers_of(rule.get("from"))]
    for rule in spec.get("egress") or []:
        edges += [(me, peer, ports(rule)) for peer in peers_of(rule.get("to"))]
    return edges


OPEN = ("entity", "open", "tout : internet + cluster")


def is_template(p):
    sel = (p["doc"].get("spec") or {}).get("endpointSelector") or {}
    return TEMPLATE_LABEL in {strip(k) for k in sel.get("matchLabels") or {}}


def open_egress(pols, extra_ns=()):
    """Who can still leave towards anything, today.

    An egress policy only restricts the pods its selector picks; the others
    in the namespace stay open, and so do the picked ones while the policy is
    only proposed. Drawn as flows of their own, solid since they are the
    current state:
      - the rest of the namespace ("tous les pods" when nothing restricts
        egress there at all, "autres pods" when some selector does);
      - every pod a proposed egress policy would restrict, until it is on.
    A namespace whose deployed egress policy selects every pod gets nothing.
    """
    def restricts(spec):
        return bool(spec.get("egress")) or "Egress" in (spec.get("policyTypes") or [])

    def selector(p):
        spec = p["doc"].get("spec") or {}
        return spec.get("endpointSelector", spec.get("podSelector")) or {}

    owners = defaultdict(set)
    for ns, app in extra_ns:
        owners[ns].add(app)
    active, proposed = defaultdict(dict), defaultdict(dict)
    for p in pols:
        if is_template(p):
            continue
        owners[p["ns"]].add(p["app"])
        if restricts(p["doc"].get("spec") or {}):
            sel = selector(p)
            (active if p["active"] else proposed)[p["ns"]][selector_name(sel)] = p["doc"]["metadata"]["name"]

    edges = []
    for ns, apps in sorted(owners.items()):
        if "tous les pods" in active[ns]:
            continue
        rest = "autres pods" if active[ns] or proposed[ns] else "tous les pods"
        edges.append({"src": ("ns", ns, rest), "dst": OPEN, "ports": {"egress non restreint"},
                      "active": True, "apps": apps})
        for sel, name in sorted(proposed[ns].items()):
            if sel not in active[ns]:
                edges.append({"src": ("ns", ns, sel), "dst": OPEN,
                              "ports": {f"egress non restreint tant que {name} est désactivée"},
                              "active": True, "apps": apps})
    return edges


def upstream_hosts(apps):
    """hostname -> node for the Ingresses an upstream chart renders from the
    valuesObject its Application carries (authentik's server.ingress.hosts,
    dex's ingress.hosts...). The chart itself is not fetched, so the Service
    is unknown: the node is the release, plus the values key that holds the
    ingress (`authentik / server`)."""
    found = {}

    def hosts_of(ing):
        out = []
        for h in ing.get("hosts") or []:
            out.append(h if isinstance(h, str) else (h or {}).get("host") or (h or {}).get("name"))
        out.append(ing.get("hostname") or ing.get("host"))
        return [h for h in out if isinstance(h, str) and "." in h]

    def walk(node, path, app):
        if not isinstance(node, dict):
            return
        ing = node.get("ingress")
        if isinstance(ing, dict) and ing.get("enabled", True) is not False:
            src = app["spec"]["source"]
            release = (src.get("helm") or {}).get("releaseName") or app["metadata"]["name"]
            label = " / ".join([release, *path]) + f" (chart {src['chart']})"
            for h in hosts_of(ing):
                found.setdefault(h, ("ns", app["spec"]["destination"].get("namespace", "default"), label))
        for k, v in sorted(node.items()):
            if k != "ingress":
                walk(v, path + [k], app)

    for app in apps:
        walk(((app["spec"]["source"].get("helm") or {}).get("valuesObject")) or {}, [], app)
    return found


def backends(routes, upstream):
    """hostname -> backend node, from the IngressRoutes and Ingresses the
    charts render, then from the ingresses upstream charts are asked for.
    Rank: a route rendered here beats an upstream guess, and a plain
    `Host(...)` route beats the auxiliary ones (authentik outpost paths) a
    host may also carry."""
    found = {h: (n, 0) for h, n in upstream_hosts(upstream).items()}
    patterns = []

    def offer(host, node, rank):
        if host not in found or rank > found[host][1]:
            found[host] = (node, rank)

    for doc, release_ns in routes:
        ns = doc["metadata"].get("namespace") or release_ns
        spec = doc.get("spec") or {}
        if doc["kind"] == "IngressRoute":
            for r in spec.get("routes") or []:
                svcs = r.get("services") or []
                if not svcs:
                    continue
                svc = svcs[0]
                node = ("ns", svc.get("namespace") or ns, "svc " + svc["name"])
                for host in re.findall(r"Host\(`([^`]+)`\)", r.get("match", "")):
                    offer(host, node, 2 if r["match"].strip() == f"Host(`{host}`)" else 1)
                patterns += [(pat, node) for pat in re.findall(r"HostRegexp\(`([^`]+)`\)", r.get("match", ""))]
        else:
            for rule in spec.get("rules") or []:
                paths = (rule.get("http") or {}).get("paths") or []
                svc = (paths[0].get("backend") or {}).get("service") if paths else None
                if rule.get("host") and svc:
                    offer(rule["host"], ("ns", ns, "svc " + svc["name"]), 2)
    # Most specific first, so `.+` (the error-pages catch-all) only gets what
    # nothing else claims.
    patterns.sort(key=lambda pn: -len(pn[0]))
    return {h: n for h, (n, _) in found.items()}, patterns


def via_traefik(pols, standalone, hosts, patterns):
    """Thick edges from the pods a policy selects to the backend of each name
    in its weebo.io/reaches annotation, and the same for the standalone
    ciliumNetworkPolicies.reaches entries (NetflowReaches). `*` stands for
    every *.weebo.poc name an exact route resolves (intercepted public names
    such as mise-versions.jdx.dev are for workspaces, not for whoever asks)."""
    def resolve(host):
        if host in hosts:
            return hosts[host]
        for pat, node in patterns:
            if re.fullmatch(pat.strip("^$"), host):
                return node
        return ("ns", "traefik", f"{host} (route introuvable)")

    sources = []
    for p in pols:
        reaches = (p["doc"]["metadata"].get("annotations") or {}).get("weebo.io/reaches")
        if reaches and not is_template(p):
            spec = p["doc"].get("spec") or {}
            sel = spec.get("endpointSelector", spec.get("podSelector")) or {}
            sources.append((("ns", p["ns"], selector_name(sel)), reaches.split(","), p["app"]))
    for entry, app in standalone:
        sources.append((("ns", entry["namespace"], selector_name(entry["endpointSelector"] or {})),
                        entry["hosts"], app))

    merged = {}
    for src, names, app in sources:
        names = sorted(h for h in hosts if h.endswith(".weebo.poc")) if "*" in names else names
        for host in names:
            dst = resolve(host)
            e = merged.setdefault((src, dst), {"src": src, "dst": dst, "hosts": set(), "active": True,
                                               "via": True, "apps": set()})
            e["hosts"].add(host)
            e["apps"].add(app)
    for e in merged.values():
        e["ports"] = {"via Traefik : " + ", ".join(sorted(e.pop("hosts")))}
    return list(merged.values())


def all_edges(pols, extra_ns=()):
    """[(src, dst, ports, active, policy)] with ports merged per pair."""
    merged = {}
    for p in pols:
        fn = cilium_edges if p["doc"]["kind"] == "CiliumNetworkPolicy" else k8s_edges
        for src, dst, ports in fn(p):
            key = (src, dst, p["active"])
            e = merged.setdefault(key, {"src": src, "dst": dst, "ports": set(), "active": p["active"], "apps": set()})
            e["ports"].update(ports or ["tous ports"])
            e["apps"].add(p["app"])
    edges = list(merged.values()) + open_egress(pols, extra_ns)
    return sorted(edges, key=lambda e: (e["src"], e["dst"], not e["active"]))


# ── Mermaid ──────────────────────────────────────────────────────────────────


def node_id(node):
    return "n_" + re.sub(r"[^A-Za-z0-9]", "_", "_".join(node[:2]))[:80] + "_" + hashlib.sha1(repr(node).encode()).hexdigest()[:6]


def esc(text):
    return text.replace('"', "#quot;")


def port_sort(p):
    m = re.search(r"(\d+)", p)
    return (int(m.group(1)) if m else 0, p)


def mermaid(edges):
    nodes = sorted({e["src"] for e in edges} | {e["dst"] for e in edges})
    lines = ["flowchart LR"]
    by_ns = defaultdict(list)
    for n in nodes:
        if n[0] == "ns":
            by_ns[n[1]].append(n)
        else:
            shape = {"entity": ('(["', '"])'), "cidr": ('[/"', '"/]'), "fqdn": ('[/"', '"/]')}[n[0]]
            label = n[2] if n == OPEN else {"entity": "entité: ", "cidr": "CIDR ", "fqdn": "FQDN<br/>"}[n[0]] + n[2]
            lines.append(f'  {node_id(n)}{shape[0]}{esc(label)}{shape[1]}')
    for ns in sorted(by_ns):
        sid = "ns_" + re.sub(r"[^A-Za-z0-9]", "_", ns)
        lines.append(f'  subgraph {sid}["{esc(ns)}"]')
        for n in by_ns[ns]:
            lines.append(f'    {node_id(n)}["{esc(n[2])}"]')
        lines.append("  end")
    for e in edges:
        label = ", ".join(sorted(e["ports"], key=port_sort))
        arrow = "==>" if e.get("via") else "-->" if e["active"] else "-.->"
        lines.append(f'  {node_id(e["src"])} {arrow}|"{esc(label)}"| {node_id(e["dst"])}')
    return "\n".join(lines)


# ── Pages ────────────────────────────────────────────────────────────────────

LEGEND = """- Une **flèche pleine** est un flux autorisé par une politique déployée aujourd'hui.
- Une **flèche pointillée** est un flux qu'une politique `weebo-base` encore désactivée (`ciliumNetworkPolicies.enabled: false`) autoriserait.
- Un cadre est un namespace, une boîte un ensemble de pods (« tous les pods » = sélecteur vide).
- Une **flèche épaisse** « via Traefik » relie un workload au backend qu'il atteint par un nom `*.weebo.poc` (annotation `weebo.io/reaches`, backend tiré des IngressRoute/Ingress du dépôt, ou du bloc `ingress` des values d'un chart upstream). C'est une relation applicative : la politique ne contrôle que le saut vers Traefik, c'est Traefik qui ouvre la connexion vers le backend.
- `tout : internet + cluster` marque des pods qu'aucune politique déployée ne restreint en sortie : ils peuvent joindre n'importe quelle destination, IP directe comprise. « autres pods » désigne ceux du namespace qu'aucune politique d'egress ne sélectionne, et un pod visé par une politique proposée reste ouvert tant qu'elle est désactivée.
- L'entité `host` sans port n'est pas dessinée : chaque politique `weebo-base` la laisse entrer (sondes kubelet, apiserver vers les webhooks).
- Une politique qui ne liste que de l'ingress laisse l'egress ouvert, et inversement."""


def policy_table(pols):
    rows = ["| Namespace | Politique | Type | État | Chart |", "|---|---|---|---|---|"]
    for p in sorted(pols, key=lambda p: (p["ns"], p["doc"]["metadata"]["name"])):
        kind = "Cilium" if p["doc"]["kind"] == "CiliumNetworkPolicy" else "Kubernetes"
        state = "déployée" if p["active"] else "proposée"
        rows.append(f"| {p['ns']} | `{p['doc']['metadata']['name']}` | {kind} | {state} | `{p['chart']}` |")
    return "\n".join(rows)


def page(title, description, body):
    return f"---\ntitle: \"{title}\"\ndescription: \"{description}\"\n---\n\n{GENERATED}\n\n{body}\n"


def main():
    pols, skipped, routes, upstream, reaches = policies()
    if not pols:
        sys.exit("netflow: no policy rendered, refusing to wipe the docs")
    edges = all_edges(pols, [(e["namespace"], a) for e, a in reaches]) + via_traefik(pols, reaches, *backends(routes, upstream))
    edges.sort(key=lambda e: (e["src"], e["dst"], not e["active"]))
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.mdx"):
        old.unlink()

    # An app with no policy of its own but a reaches entry (vpn) gets a page too.
    apps = sorted({p["app"] for p in pols} | {a for _, a in reaches})
    app_ns = {a: {p["ns"] for p in pols if p["app"] == a} | {e["namespace"] for e, b in reaches if b == a}
              for a in apps}

    skipped_md = "\n".join(f"- `{c}` ({a}) : {why}" for c, a, why in skipped) or "- aucun"
    links = "\n".join(f"- [{a}](/docs/security/network-flows/{a})" for a in apps)
    body = f"""Les flux réseau que les NetworkPolicies et CiliumNetworkPolicies du dépôt autorisent, tirés du rendu Helm de chaque chart d'application Argo CD. Le schéma global est volontairement exhaustif, donc illisible : il sert à voir la forme de l'ensemble. Le détail se lit par application.

## Légende

{LEGEND}

## Régénérer

```sh
task docs:netflow
```

Le hook `pre-commit` (cog.toml) la lance dès qu'un commit touche `2.argo/helm`, `2.helm` ou le générateur, et ajoute le résultat au commit.

## Par application

{links}

## Schéma global

```mermaid
{mermaid(edges)}
```

## Politiques

{policy_table(pols)}

## Charts non dessinés

{skipped_md}
"""
    (OUT / "index.mdx").write_text(page("Flux réseau", "Les flux autorisés par les politiques réseau du cluster", body))

    for a in apps:
        mine = [e for e in edges if a in e["apps"]]
        # Flows other apps open towards this app's namespaces, or from them.
        related = [e for e in edges if a not in e["apps"] and
                   ((e["src"][0] == "ns" and e["src"][1] in app_ns[a]) or (e["dst"][0] == "ns" and e["dst"][1] in app_ns[a]))]
        related_md = ""
        if related:
            related_md = f"""
## Flux ouverts par d'autres applications

Les politiques d'autres applications qui touchent les namespaces de `{a}`.

```mermaid
{mermaid(related)}
```
"""
        body = f"""Les flux que les politiques de l'application Argo CD `{a}` autorisent. Namespaces : {", ".join(f"`{n}`" for n in sorted(app_ns[a]))}.

## Légende

{LEGEND}

## Flux

```mermaid
{mermaid(mine)}
```
{related_md}
## Politiques

{policy_table([p for p in pols if p["app"] == a])}
"""
        (OUT / f"{a}.mdx").write_text(page(f"Flux réseau : {a}", f"Les flux autorisés par les politiques réseau de {a}", body))

    (OUT / "meta.json").write_text(json.dumps({"title": "Flux réseau", "pages": ["index", *apps]}, indent=2) + "\n")
    print(f"netflow: {len(pols)} policies, {len(edges)} flows, {len(apps)} apps -> {OUT.relative_to(ROOT)}")
    for c, a, why in skipped:
        print(f"netflow: skipped {c} ({a}): {why}", file=sys.stderr)


if __name__ == "__main__":
    main()
