#!/usr/bin/env python3
"""Draw the authentication chain of the cluster as Mermaid, into the docs.

The twin of netflow.py: the same render of the app of apps (argorender.py),
read for what authenticates whom instead of what reaches what. Writes under
0.docs/content/docs/security/authentication/ an overview, the groups and who
they open, the Authentik flows, the Kubernetes chain and one section per
Authentik application.

What it reads, all from git:

- the Authentik CRs of 2.argo/helm/auth/sub (weebo-authentik operator):
  groups, users, applications and their access policies, flows, blueprints,
  scope mappings;
- who consumes each application: the operator writes the client to Vault
  (`secretTargets`), an ExternalSecret or a `vault:` injection reads it back
  into a namespace, and whatever names that Secret is the consumer. An
  `/application/o/<slug>/` URL counts too (Forgejo's autoDiscoverUrl);
- the Dex brokers: the dex chart's valuesObject (auth/main), and Argo CD's
  own Dex, whose dex.config and policy.csv live in 1.pulu-conf/main.go;
- Traefik forwardAuth middlewares pointing at the Authentik outpost, and the
  IngressRoutes using them (the proxy applications);
- the apiserver's AuthenticationConfiguration (1.pulu-init/main.go), the
  kubeconfig template (0.config/kubeconfig.oidc-template.yaml) and every
  RoleBinding/ClusterRoleBinding with a Group or User subject.

The two Go files are read with regular expressions: when one no longer
matches, the script stops and says which, rather than drawing a wrong chain.

    task docs:authflow
"""
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from argorender import REPO, ROOT, walk, yaml_docs  # noqa: E402

OUT = ROOT / "0.docs/content/docs/security/authentication"
PULU_CONF = ROOT / "1.pulu-conf/main.go"
PULU_INIT = ROOT / "1.pulu-init/main.go"
KUBECONFIG = ROOT / "0.config/kubeconfig.oidc-template.yaml"
GENERATED = "{/* Généré par `task docs:authflow` (0.task/scripts/authflow.py). Ne pas éditer à la main. */}"
DOCS = "/docs/security/authentication"


def fail(msg):
    sys.exit(f"authflow: {msg} -- the source moved, update 0.task/scripts/authflow.py")


# ── Walking JSON ─────────────────────────────────────────────────────────────


def leaves(o, path=""):
    """(path, key, value) for every key and every string value."""
    if isinstance(o, dict):
        for k, v in o.items():
            yield f"{path}.{k}", k, None
            yield from leaves(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from leaves(v, f"{path}[{i}]")
    elif isinstance(o, str):
        yield path, None, o


def strings(o):
    return [v for _, _, v in leaves(o) if v is not None]


def doc_ns(d, default):
    if d.get("kind") == "Application":
        return ((d.get("spec") or {}).get("destination") or {}).get("namespace") or default
    return d["metadata"].get("namespace") or default


def ref(d):
    return f"{d['kind']}/{d['metadata']['name']}"


# ── Collecting ───────────────────────────────────────────────────────────────


def collect():
    docs, skipped = [], []
    for r in walk():
        if r.live is None:
            skipped.append((r.chart, r.app or "app of apps", r.err))
            continue
        docs += [{"app": r.app or "app of apps", "chart": r.chart, "ns": doc_ns(d, r.namespace), "doc": d}
                 for d in r.live if isinstance(d, dict) and d.get("kind")]
    return docs, skipped


def of_kind(docs, kind):
    return [x for x in docs if x["doc"]["kind"] == kind]


def authentik(docs):
    groups = {x["doc"]["spec"]["name"]: x["doc"]["spec"] for x in of_kind(docs, "AuthentikGroup")}
    users = {x["doc"]["spec"]["username"]: x["doc"]["spec"] for x in of_kind(docs, "AuthentikUser")}
    access = defaultdict(list)
    for x in of_kind(docs, "AuthentikAccessPolicy"):
        s = x["doc"]["spec"]
        access[s["applicationRef"]].append((s.get("order", 0), s.get("groupRef") or s.get("userRef") or "?"))
    apps = {}
    for x in of_kind(docs, "AuthentikApplication"):
        d = x["doc"]
        s = d["spec"]
        kind = s["provider"]["kind"]
        apps[d["metadata"]["name"]] = {
            "cr": d["metadata"]["name"], "slug": s["slug"], "name": s.get("name", s["slug"]), "kind": kind,
            "provider": s["provider"].get(kind) or {}, "secretTargets": s.get("secretTargets") or [],
            "access": [g for _, g in sorted(access.get(d["metadata"]["name"], []))],
        }
    flows = {x["doc"]["spec"]["slug"]: {**x["doc"]["spec"], "source": f"AuthentikFlow `{x['doc']['metadata']['name']}`"}
             for x in of_kind(docs, "AuthentikFlow")}
    blueprints = []
    for x in of_kind(docs, "AuthentikBlueprint"):
        s = x["doc"]["spec"]
        content = (yaml_docs(s.get("content") or "") or [{}])[0]
        entries = content.get("entries") or []
        bp = {"cr": x["doc"]["metadata"]["name"], "name": s.get("name") or content.get("metadata", {}).get("name"),
              "description": ((content.get("metadata") or {}).get("labels") or {}).get("blueprints.goauthentik.io/description", ""),
              "entries": entries}
        blueprints.append(bp)
        for e in entries:
            if e.get("model") == "authentik_flows.flow":
                slug = (e.get("identifiers") or {}).get("slug")
                stages = [st for st in entries if st.get("model", "").startswith("authentik_stages_")]
                flows[slug] = {**(e.get("attrs") or {}), "slug": slug, "source": f"blueprint `{bp['cr']}`",
                               "stages": stages}
    mappings = {x["doc"]["spec"]["name"]: x["doc"]["spec"] for x in of_kind(docs, "AuthentikScopeMapping")}
    instance = (of_kind(docs, "AuthentikInstance") or [{"doc": {"spec": {}}}])[0]["doc"]["spec"]
    brand = (of_kind(docs, "AuthentikBrand") or [{"doc": {"spec": {}}}])[0]["doc"]["spec"]
    return {"groups": groups, "users": users, "apps": apps, "flows": flows, "blueprints": blueprints,
            "mappings": mappings, "instance": instance, "brand": brand}


def ancestors(groups, g):
    out, seen = [], set()
    while g and g not in seen:
        seen.add(g)
        out.append(g)
        g = (groups.get(g) or {}).get("parentRef")
    return out


def effective_groups(ak, username):
    out = []
    for g in ak["users"][username].get("groupRefs") or []:
        out += [a for a in ancestors(ak["groups"], g) if a not in out]
    return out


def members(ak, group):
    """Users who pass a binding on `group`: direct members of it or of any
    group below it (Authentik counts the parents of a user's groups)."""
    return sorted(u for u in ak["users"] if group in effective_groups(ak, u))


# ── Pulumi side (Go, read with regexes) ──────────────────────────────────────


def go_string(text, key):
    m = re.search(r'"' + re.escape(key) + r'":\s*pulumi\.String\(`(.*?)`\)', text, re.S)
    if not m:
        m = re.search(r'"' + re.escape(key) + r'":\s*pulumi\.String\("((?:[^"\\]|\\.)*)"\)', text)
    return m.group(1) if m else None


def argocd():
    text = PULU_CONF.read_text()
    dex_config = go_string(text, "dex.config")
    policy = go_string(text, "policy.csv")
    if dex_config is None or policy is None:
        fail(f"no dex.config / policy.csv in {PULU_CONF.relative_to(ROOT)}")
    cfg = (yaml_docs(dex_config) or [{}])[0]
    roles = []
    for line in policy.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) == 3 and parts[0] == "g":
            roles.append((parts[1], parts[2]))
    # A pseudo-document, so the secret chain finds Argo CD like any consumer.
    doc = {"kind": "ConfigMap", "metadata": {"name": "argocd-cm", "namespace": "argocd"},
           "data": {"dex.config": dex_config, "policy.csv": policy}}
    settings = {}
    for key in ARGO_SETTINGS:
        m = re.search(r'"' + re.escape(key) + r'":\s*(pulumi\.\w+\((?:[^()]|\([^()]*(?:\([^()]*\))?[^()]*\))*\))', text)
        settings[key] = m.group(1) if m else None
    # The app of apps (`main`), created by Pulumi: its project and destination.
    root = re.search(r'"name":\s*"main",(.*?)"source":', text, re.S)
    root_project = re.search(r'"project":\s*"([^"]+)"', root.group(1)) if root else None
    root_dest = re.search(r'"namespace":\s*"([^"]+)"', root.group(1).split('"destination"', 1)[-1]) if root else None
    return {"connectors": cfg.get("connectors") or [], "roles": roles, "scopes": go_string(text, "scopes") or "",
            "settings": settings, "root_project": root_project.group(1) if root_project else "?",
            "root_dest": root_dest.group(1) if root_dest else "?",
            "doc": {"app": "argocd (1.pulu-conf)", "chart": "1.pulu-conf", "ns": "argocd", "doc": doc}}


# The argocd-cm / argocd-rbac-cm / argocd-cmd-params-cm keys worth tracking,
# with what they mean; the value is shown as written in 1.pulu-conf.
ARGO_SETTINGS = {
    "admin.enabled": "compte local `admin` (mot de passe statique)",
    "exec.enabled": "terminal web dans les pods",
    "users.session.duration": "durée d'une session (24h par défaut)",
    "policy.default": "rôle de qui n'est nommé nulle part",
    "scopes": "claims lues comme groupes par le RBAC",
    "server.rbac.log.enforce.enable": "journalisation des refus RBAC",
    "server.insecure": "TLS terminé en amont (Traefik)",
}


def go_consts(text):
    consts = {}
    for name, expr in re.findall(r'^\s*(\w+)\s*=\s*("[^"\n]*"(?:\s*\+\s*(?:\w+|"[^"\n]*"))*)\s*$', text, re.M):
        parts = re.findall(r'"([^"]*)"|(\w+)', expr)
        consts[name] = "".join(lit if lit else consts.get(var, "{" + var + "}") for lit, var in parts)
    return consts


def mapping(block, key):
    m = re.search(r'"' + key + r'":\s*map\[string\]interface\{\}\{(.*?)\n\s*\},', block, re.S)
    if not m:
        fail(f"no claimMappings.{key} in authenticationConfig")
    body = m.group(1)
    e = re.search(r'"expression":\s*(?:`([^`]*)`|"((?:[^"\\]|\\.)*)")', body)
    if e:
        return {"expression": e.group(1) if e.group(1) is not None else e.group(2).replace('\\"', '"')}
    c = re.search(r'"claim":\s*"([^"]*)"', body)
    p = re.search(r'"prefix":\s*"([^"]*)"', body)
    if not c:
        fail(f"claimMappings.{key} is neither an expression nor a claim")
    return {"claim": c.group(1), "prefix": p.group(1) if p else ""}


def apiserver():
    text = PULU_INIT.read_text()
    consts = go_consts(text)
    m = re.search(r"func authenticationConfig\((.*?)\n}\n", text, re.S)
    if not m:
        fail(f"no authenticationConfig() in {PULU_INIT.relative_to(ROOT)}")
    body = m.group(1)
    rules = re.findall(r'"expression":\s*"((?:[^"\\]|\\.)*)",\s*"message"', body)
    splits = list(re.finditer(r'"issuer":\s*issuer\((\w+),\s*(\w+)\)', body))
    if not splits:
        fail("no jwt issuer in authenticationConfig")
    kube = (yaml_docs(KUBECONFIG.read_text()) or [{}])[0]
    contexts = []
    for u in kube.get("users") or []:
        args = (((u.get("user") or {}).get("exec") or {}).get("args")) or []
        opt = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in args if isinstance(a, str) and "=" in a}
        ctx = [c["name"] for c in kube.get("contexts") or [] if c["context"]["user"] == u["name"]]
        scopes = " ".join(a.split("=", 1)[1].strip('"') for a in args if isinstance(a, str) and a.startswith("--oidc-extra-scope="))
        contexts.append({"context": ", ".join(ctx), "issuer": opt.get("--oidc-issuer-url", ""),
                         "client": opt.get("--oidc-client-id", ""), "scopes": scopes})
    jwts = []
    for i, s in enumerate(splits):
        block = body[s.start():(splits[i + 1].start() if i + 1 < len(splits) else len(body))]
        url_var, aud_var = s.group(1), s.group(2)
        url, aud = consts.get(url_var), consts.get(aud_var)
        if url is None:  # a parameter of authenticationConfig: filled from Vault at apply time
            known = [c for c in contexts if c["issuer"] and not any(c["issuer"] == consts.get(v) for v in consts)]
            url = known[0]["issuer"] if known else f"({url_var})"
            aud = known[0]["client"] if known else f"({aud_var})"
            origin = "Vault (`OIDC_URL`, `OIDC_CLIENT_ID`), valeur attendue d'après le kubeconfig"
        else:
            origin = "constante de `1.pulu-init/main.go`"
        user, groups = mapping(block, "username"), mapping(block, "groups")
        jwts.append({"i": i, "issuer": url, "audience": aud, "origin": origin, "username": user, "groups": groups})
    for j in jwts:
        u = j["username"].get("expression", "")
        pm = re.search(r'"([^"]+)"\s*\+\s*claims\.(\w+)', u)
        j["user_prefix"], j["user_claim"] = (pm.group(1), pm.group(2)) if pm else ("", j["username"].get("claim", "?"))
        g = j["groups"]
        if "expression" in g:
            pm = re.search(r'"([^"]+)"\s*\+\s*g\b', g["expression"])
            j["group_prefix"] = pm.group(1) if pm else ""
            j["excluded"] = re.findall(r'g\s*!=\s*"([^"]+)"', g["expression"])
            if "filter" in g["expression"] and not j["excluded"]:
                fail("a groups filter authflow cannot read")
        else:
            j["group_prefix"], j["excluded"] = g["prefix"], []
    return {"jwts": jwts, "rules": [r.replace('\\"', '"') for r in rules], "contexts": contexts}


# ── Relations ────────────────────────────────────────────────────────────────


def secret_chains(docs, ak):
    """For each Authentik application: who reads its client back."""
    mount = ((ak["instance"].get("secretStore") or {}).get("vault") or {}).get("mount", "mv")
    skip = lambda x: x["doc"]["kind"].startswith("Authentik")  # noqa: E731
    out = defaultdict(list)
    for cr, app in ak["apps"].items():
        for t in app["secretTargets"]:
            p = t.get("path", "")
            pat = re.compile(r"(?:^|[:/])" + re.escape(mount) + r"/(?:data/)?" + re.escape(p) + r"(?:#|$)")
            for x in docs:
                if skip(x) or not any(pat.search(s) for s in strings(x["doc"])):
                    continue
                if x["doc"]["kind"] == "ExternalSecret":
                    target = ((x["doc"]["spec"].get("target") or {}).get("name")) or x["doc"]["metadata"]["name"]
                    readers = [y for y in docs if y is not x and y["ns"] == x["ns"] and not skip(y)
                               and any(s == target or f"${target}:" in s for s in strings(y["doc"]))]
                    via = f"Vault `{mount}/{p}` → ExternalSecret `{x['ns']}/{x['doc']['metadata']['name']}` → Secret `{target}`"
                    for y in readers or [None]:
                        out[cr].append({"consumer": y, "via": via, "es": x})
                else:
                    out[cr].append({"consumer": x, "via": f"Vault `{mount}/{p}` injecté (`vault:`)", "es": None})
        slug_url = f"/application/o/{app['slug']}/"
        for x in docs:
            if not skip(x) and any(slug_url in s for s in strings(x["doc"])) and \
                    not any(c["consumer"] is x for c in out[cr]):
                out[cr].append({"consumer": x, "via": f"issuer `…{slug_url}` en dur", "es": None})
    return out


def dex_broker(docs):
    """The dex chart of auth/main: its issuer, connectors and static clients."""
    for x in docs:
        d = x["doc"]
        src = (d.get("spec") or {}).get("source") or {}
        if d["kind"] == "Application" and src.get("chart") == "dex":
            cfg = ((src.get("helm") or {}).get("valuesObject") or {}).get("config") or {}
            return {"x": x, "issuer": cfg.get("issuer", ""), "connectors": cfg.get("connectors") or [],
                    "clients": cfg.get("staticClients") or []}
    return None


def dex_clients_users(docs, dex, extra):
    """Who signs in at dex: a doc naming its issuer, and the static client it
    names. extra: pseudo-consumers (kubeconfig contexts, apiserver)."""
    out = []
    if not dex:
        return out
    ids = [c["id"] for c in dex["clients"]]
    for x in docs:
        if x is dex["x"] or x["doc"]["kind"].startswith("Authentik"):
            continue
        ss = strings(x["doc"])
        if any(s == dex["issuer"] or s.startswith(dex["issuer"] + "/") for s in ss):
            named = [i for i in ids if i in ss]
            out.append({"consumer": x, "clients": named or ["?"]})
    for e in extra:
        if e["issuer"].rstrip("/") == dex["issuer"].rstrip("/"):
            out.append({"consumer": None, "label": e["label"], "clients": [e["client"]]})
    return out


def forward_auth(docs, ak):
    mws = {(x["ns"], x["doc"]["metadata"]["name"]): x for x in of_kind(docs, "Middleware")
           if "outpost.goauthentik.io" in ((x["doc"]["spec"].get("forwardAuth") or {}).get("address") or "")}
    out = []
    for x in of_kind(docs, "IngressRoute"):
        for route in x["doc"]["spec"].get("routes") or []:
            for mw in route.get("middlewares") or []:
                if (mw.get("namespace") or x["ns"], mw["name"]) in mws:
                    for host in re.findall(r"Host\(`([^`]+)`\)", route.get("match", "")):
                        apps = [cr for cr, a in ak["apps"].items() if a["kind"] == "proxy"
                                and re.sub(r"^https?://", "", a["provider"].get("externalHost", "")).rstrip("/") == host]
                        out.append({"route": x, "host": host, "middleware": f"{mw.get('namespace') or x['ns']}/{mw['name']}",
                                    "apps": apps})
    return out


def argo_visibility(docs, ak, argo):
    """username -> [(what, how)]: the Argo CD Applications a person sees.
    Global roles from policy.csv (by group), project roles from the
    AppProjects (by group or, with the email scope, by email)."""
    scopes = argo["scopes"]
    out = defaultdict(list)
    for u, spec in ak["users"].items():
        ids = set(effective_groups(ak, u))
        if "email" in scopes and spec.get("email"):
            ids.add(spec["email"])
        for gname, role in argo["roles"]:
            if gname in ids:
                out[u].append((f"tout (`{role}`)", f"`policy.csv` : `{gname}`"))
            elif gname not in ak["groups"]:
                # Not an Authentik group: a marker a scope mapping emits. The
                # person gets it through each application using that mapping
                # whose access policy they pass.
                for m in ak["mappings"].values():
                    if f'"{gname}"' not in (m.get("expression") or ""):
                        continue
                    for cr, app in ak["apps"].items():
                        if m["name"] in (app["provider"].get("propertyMappings") or []) and \
                                any(g in ids for g in app["access"]):
                            flow = app["provider"].get("authorizationFlow", "")
                            mfa = " (second facteur)" if ak["flows"].get(flow, {}).get("stages") else ""
                            out[u].append((f"tout (`{role}`)", f"`policy.csv` : `{gname}`, émis par le mapping "
                                           f"`{m['name']}` de l'application `{app['slug']}`{mfa}"))
        for x in of_kind(docs, "AppProject"):
            for r in x["doc"]["spec"].get("roles") or []:
                hit = sorted(ids & set(r.get("groups") or []))
                if not hit:
                    continue
                objs = defaultdict(set)
                for pol in r.get("policies") or []:
                    parts = [q.strip() for q in pol.split(",")]
                    if len(parts) == 6 and parts[2] == "applications" and parts[5] == "allow":
                        objs[parts[4]].add(parts[3])
                for obj, acts in sorted(objs.items()):
                    out[u].append((f"`{obj}` ({', '.join(sorted(acts))})",
                                   f"rôle `proj:{x['doc']['metadata']['name']}:{r['name']}` : `{hit[0]}`"))
    return out


def bindings(docs):
    out = []
    for x in docs:
        if x["doc"]["kind"] not in ("ClusterRoleBinding", "RoleBinding"):
            continue
        for s in x["doc"].get("subjects") or []:
            if s.get("kind") in ("Group", "User") and not s["name"].startswith("system:"):
                out.append({"x": x, "subject": s, "role": x["doc"]["roleRef"]})
    return out


def group_mentions(docs, ak, argo):
    """Where a downstream system grants something to an Authentik group."""
    names = set(ak["groups"])
    out = defaultdict(list)
    ignore_kinds = {"AuthentikGroup", "AuthentikUser", "AuthentikAccessPolicy", "AuthentikApplication",
                    "WeeboSiUser", "ForgejoRepository", "ForgejoOrganization"}
    for x in docs + [argo["doc"]]:
        if x["doc"]["kind"] in ignore_kinds:
            continue
        for path, key, val in leaves(x["doc"]):
            if path.endswith((".username", ".owner")):
                continue
            for g in names:
                hit = key == g if key is not None else (
                    val == g or re.fullmatch(r"[\w-]+:" + re.escape(g), val)
                    or (len(val) > len(g) + 2 and re.search(r'(?:"|\bg,\s*)' + re.escape(g) + r'(?:"|,)', val)))
                if hit:
                    out[g].append((x, path))
    return out


# ── Mermaid ──────────────────────────────────────────────────────────────────


def nid(*key):
    raw = "_".join(key)
    return "n_" + re.sub(r"[^A-Za-z0-9]", "_", raw)[:60] + "_" + hashlib.sha1(raw.encode()).hexdigest()[:6]


def esc(text):
    return str(text).replace('"', "#quot;")


class Chart:
    def __init__(self, direction="LR"):
        self.lines = [f"flowchart {direction}"]
        self.groups = defaultdict(list)  # subgraph title -> node lines
        self.free, self.edges, self.known = [], [], set()

    def node(self, key, label, sub=None, shape="box"):
        i = nid(*key)
        if i not in self.known:
            self.known.add(i)
            o, c = {"box": ('["', '"]'), "round": ('("', '")'), "stadium": (('(["', '"])')),
                    "hex": ('{{"', '"}}'), "para": ('[/"', '"/]')}[shape]
            line = f"{i}{o}{esc(label)}{c}"
            (self.groups[sub] if sub else self.free).append(line)
        return i

    def edge(self, a, b, label="", style="-->"):
        lab = f'|"{esc(label)}"|' if label else ""
        line = f"  {a} {style}{lab} {b}"
        if line not in self.edges:
            self.edges.append(line)

    def render(self):
        out = list(self.lines)
        out += [f"  {l}" for l in self.free]
        for title, nodes in self.groups.items():
            out.append(f'  subgraph {nid("sg", title)}["{esc(title)}"]')
            out += [f"    {l}" for l in nodes]
            out.append("  end")
        return "\n".join(out + self.edges)


def consumer_label(x):
    return f"{ref(x['doc'])}<br/>({x['app']})"


def app_label(a, ak):
    flow = a["provider"].get("authorizationFlow", "")
    tags = [a["kind"] if a["kind"] != "oauth2" else ("oauth2 public" if a["provider"].get("clientType") == "public" else "oauth2")]
    if flow and "explicit" in flow:
        tags.append("consentement")
    if flow and flow in ak["flows"] and ak["flows"][flow].get("stages"):
        tags.append("2FA")
    return f"{a['slug']}<br/>{' · '.join(tags)}"


# ── Pages ────────────────────────────────────────────────────────────────────

LEGEND = """- Un **groupe** donne accès à une application Authentik par une politique d'accès (`AuthentikAccessPolicy`). Les membres d'un groupe enfant passent aussi les politiques de ses parents : `weebo_admin` ⊂ `weebo_moderator` ⊂ `weebo_user`.
- Une flèche **Authentik → consommateur** suit le client OIDC : l'opérateur écrit `client_id`/`client_secret` dans Vault (`secretTargets`), un `ExternalSecret` ou une injection `vault:` le relit dans un namespace, et l'objet qui nomme ce Secret est le consommateur. Une URL `/application/o/<slug>/` en dur compte aussi.
- Une flèche **épaisse** (`==>`) passe par une étape de second facteur (flux d'autorisation à étape `authenticator_validate`, ici `admin-step-up`).
- Les **Dex** sont des courtiers : ils se connectent à Authentik comme un client, puis émettent leurs propres jetons à leurs clients statiques.
- Les **proxys** Authentik sont servis par le middleware Traefik `forwardAuth` : l'IngressRoute n'atteint le backend qu'après l'avant-poste Authentik.
- Côté Kubernetes, l'apiserver accepte deux émetteurs JWT (`AuthenticationConfiguration` de `1.pulu-init`), et les (Cluster)RoleBindings donnent les droits aux noms préfixés qu'ils produisent."""


def page(title, description, body):
    return f"---\ntitle: \"{title}\"\ndescription: \"{description}\"\n---\n\n{GENERATED}\n\n{body}\n"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(str(c).replace("|", "\\|").replace("\n", " ") for c in r) + " |" for r in rows]
    return "\n".join(out)


def code(v):
    if v in (None, ""):
        return "—"
    v = str(v)
    return f"`` {v} ``" if "`" in v else f"`{v}`"


def mdcode(text):
    """Multi-line code in a table cell: one inline span per line, so MDX
    never sees a brace or a tag outside code."""
    lines = str(text).strip("\n").splitlines()
    # Leading spaces as no-break spaces: an inline span would drop them.
    return "<br/>".join(code("\u00a0" * (len(l) - len(l.lstrip(" "))) + l.lstrip(" ")) for l in lines) or "—"


def jwt_label(j):
    return f"apiserver jwt[{j['i']}]<br/>{j['user_prefix']}{j['user_claim']}"


def group_reach(j, group):
    return group not in j["excluded"]


def jwt_sources(api, dex, ak, chains):
    """Which Authentik application stands behind each jwt issuer."""
    out = {}
    for j in api["jwts"]:
        app = next((cr for cr, a in ak["apps"].items() if j["issuer"].rstrip("/").endswith(f"/application/o/{a['slug']}")), None)
        if app:
            out[j["i"]] = ("authentik", app)
        elif dex and j["issuer"].rstrip("/") == dex["issuer"].rstrip("/"):
            out[j["i"]] = ("dex", dex_upstream(dex, ak, chains))
        else:
            out[j["i"]] = ("other", None)
    return out


def dex_upstream(dex, ak, chains):
    """The Authentik application whose client Dex reads (its connector)."""
    for cr, cs in chains.items():
        if any(c["consumer"] is dex["x"] for c in cs):
            return cr
    return None


def argo_page(docs, ak, argo, chains):
    projects = {x["doc"]["metadata"]["name"]: x for x in of_kind(docs, "AppProject")}
    apps = defaultdict(list)
    for x in of_kind(docs, "Application"):
        apps[x["doc"]["spec"].get("project", "default")].append(x["doc"]["metadata"]["name"])
    apps[argo["root_project"]].append("main (1.pulu-conf)")
    # Created at runtime, not rendered: weebo-si-operator's per-user ones.
    for x in of_kind(docs, "WeeboSiUser"):
        u = x["doc"]["spec"].get("username", x["doc"]["metadata"]["name"])
        apps["che-users"].append(f"che-user-{x['doc']['metadata']['name']} (weebo-si-operator)")
        ext = (((x["doc"]["spec"].get("che") or {}).get("values") or {}).get("cheUser") or {}).get("externalConfig") or {}
        if ext.get("enabled"):
            apps[f"che-config-{u}"].append(f"{u}-external-config (2.helm/user-app)")
    locked = "default" in projects and not projects["default"]["doc"]["spec"].get("sourceRepos")

    # Who signs in through which connector, and what that gives.
    c = Chart()
    ai = c.node(("argocd",), "Argo CD", "Argo CD", "hex")
    for conn in argo["connectors"]:
        cfg = conn.get("config") or {}
        iss = cfg.get("issuer", "")
        ci = c.node(("conn", conn.get("id", "?")), f"connecteur {conn.get('id')}<br/>{conn.get('name', '')}", "Dex d'Argo CD", "hex")
        src = None
        if iss.startswith("$"):
            secret = iss[1:].split(":")[0]
            src = next((cr for cr, cs in chains.items() for ch in cs if ch["consumer"] is argo["doc"] and f"Secret `{secret}`" in ch["via"]), None)
        if src:
            a = ak["apps"][src]
            mfa = a["provider"].get("authorizationFlow") in ak["flows"] and ak["flows"][a["provider"]["authorizationFlow"]].get("stages")
            c.edge(c.node(("ak", src), app_label(a, ak), "Authentik"), ci, "", "==>" if mfa else "-->")
            for gr in a["access"]:
                c.edge(c.node(("group", gr), gr, "Groupes Authentik", "round"), c.node(("ak", src), "", "Authentik"), "accès")
        else:
            c.edge(c.node(("ext", iss), iss, "Émetteurs externes", "para"), ci, "")
        c.edge(ci, ai, "groupes" if cfg.get("insecureEnableGroups") else "sans groupes")
    for gname, role in argo["roles"]:
        c.edge(c.node(("claim", gname), gname, "Claims groups", "round"), c.node(("role", role), role, "Rôles Argo CD", "stadium"), "policy.csv")
    for name, x in sorted(projects.items()):
        for r in x["doc"]["spec"].get("roles") or []:
            for g in r.get("groups") or []:
                c.edge(c.node(("claim", g), g, "Claims groups", "round"),
                       c.node(("prole", name, r["name"]), f"proj:{name}:{r['name']}", f"Projet {name}", "stadium"), "rôle de projet")

    set_rows = [[code(k), code(v), why] for k, why in ARGO_SETTINGS.items() for v in [argo["settings"].get(k)]]
    conn_rows = []
    for conn in argo["connectors"]:
        cfg = conn.get("config") or {}
        conn_rows.append([code(conn.get("id")), conn.get("name", ""), code(cfg.get("issuer")),
                          "oui" if cfg.get("insecureEnableGroups") else "non", code(cfg.get("userNameKey", "défaut"))])
    role_rows = [[code(g), code(r), "groupe Authentik" if g in ak["groups"] else "marqueur émis par un mapping"] for g, r in argo["roles"]]
    proj_rows, prole_rows = [], []
    for name, x in sorted(projects.items()):
        sp = x["doc"]["spec"]
        dests = ", ".join(code(d.get("namespace")) for d in sp.get("destinations") or []) or "aucune"
        ckinds = ", ".join(code(w["kind"]) for w in sp.get("clusterResourceWhitelist") or []) or "aucun"
        nkinds = ("tous" if sp.get("namespaceResourceWhitelist") is None else
                  ", ".join(code(w["kind"]) for w in sp["namespaceResourceWhitelist"]) or "aucun")
        proj_rows.append([code(name), "<br/>".join("ce dépôt" if r == REPO else code(r) for r in sp.get("sourceRepos") or []) or "aucune", dests, ckinds, nkinds,
                          "<br/>".join(code(a) for a in sorted(apps.get(name, []))) or "—", code(x["app"])])
        for r in sp.get("roles") or []:
            prole_rows.append([code(name), code(r["name"]), ", ".join(code(g) for g in r.get("groups") or []),
                               "<br/>".join(code(p) for p in r.get("policies") or [])])
    default_apps = sorted(apps.get("default", []))
    if locked:
        default_md = "Verrouillé (`2.argo/app`, `lockDefaultProject: true`) : aucune source, aucune destination."
    else:
        default_md = ("**Non verrouillé** : le projet intégré d'Argo CD permet tout (`lockDefaultProject: false` dans `2.argo/app/values.yaml`). "
                      + ("Applications qui l'utilisent encore : " + ", ".join(code(a) for a in default_apps) + "." if default_apps
                         else "Plus aucune Application ne l'utilise : il peut être verrouillé."))
    body = f"""Comment on entre dans Argo CD et ce que chacun y peut, d'après `1.pulu-conf/main.go` (Dex, RBAC, réglages) et les AppProjects rendus par les charts. Ce que décrit `1.pulu-conf` n'est en place qu'après `pulumi up`.

```mermaid
{c.render()}
```

## Réglages

{table(["Clé", "Valeur (1.pulu-conf)", "Rôle"], set_rows)}

## Connecteurs Dex

{table(["Connecteur", "Nom", "Émetteur", "Groupes transmis", "Nom d'utilisateur"], conn_rows)}

Un connecteur sans groupes ni email n'obtient que ce qu'un rôle de projet donne à son nom d'utilisateur ; `policy.default` donne le reste.

## Rôles globaux (`policy.csv`)

{table(["Claim", "Rôle", "Nature"], role_rows)}

## Projets

L'app of apps `main` est dans le projet {code(argo['root_project'])}, destination {code(argo['root_dest'])} (`1.pulu-conf`).

Projet `default` : {default_md}

{table(["Projet", "Sources", "Destinations", "Types cluster", "Types namespacés", "Applications", "Rendu par"], proj_rows)}

## Rôles de projet

{table(["Projet", "Rôle", "Sujets", "Politiques"], prole_rows) if prole_rows else "Aucun."}
"""
    (OUT / "argocd.mdx").write_text(page("Argo CD", "Connecteurs, rôles et projets d'Argo CD", body))


def main():
    docs, skipped = collect()
    ak = authentik(docs)
    if not ak["apps"]:
        sys.exit("authflow: no AuthentikApplication rendered, refusing to wipe the docs")
    argo = argocd()
    api = apiserver()
    all_docs = docs + [argo["doc"]]
    chains = secret_chains(all_docs, ak)
    dex = dex_broker(docs)
    extra = [{"label": f"kubeconfig `{c['context']}`", "issuer": c["issuer"], "client": c["client"]} for c in api["contexts"]] + \
            [{"label": f"apiserver jwt[{j['i']}]", "issuer": j["issuer"], "client": j["audience"]} for j in api["jwts"]]
    dex_users = dex_clients_users(docs, dex, extra)
    fwd = forward_auth(docs, ak)
    rbs = bindings(docs)
    mentions = group_mentions(docs, ak, argo)
    jsrc = jwt_sources(api, dex, ak, chains)
    dex_app = dex_upstream(dex, ak, chains) if dex else None
    offcluster = defaultdict(list)  # Authentik app -> kubeconfig contexts / apiserver issuers on its issuer
    for e in extra:
        for cr, a in ak["apps"].items():
            if e["issuer"].rstrip("/").endswith(f"/application/o/{a['slug']}"):
                offcluster[cr].append(e["label"])
    step_up = {cr for cr, a in ak["apps"].items()
               if ak["flows"].get(a["provider"].get("authorizationFlow", ""), {}).get("stages")}

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.mdx"):
        old.unlink()

    # ── Global chart ──
    g = Chart()
    AK = f"Authentik ({ak['instance'].get('url', 'auth')})"
    for name, spec in ak["groups"].items():
        lab = name + (" (superuser)" if spec.get("isSuperuser") else "")
        gi = g.node(("group", name), lab, "Groupes Authentik", "round")
        if spec.get("parentRef"):
            g.edge(gi, g.node(("group", spec["parentRef"]), spec["parentRef"], "Groupes Authentik", "round"), "inclus dans", "-.->")
    for u, spec in ak["users"].items():
        ui = g.node(("user", u), f"👤 {u}", "Utilisateurs", "stadium")
        for gr in spec.get("groupRefs") or []:
            g.edge(ui, g.node(("group", gr), gr, "Groupes Authentik", "round"), "membre")
    for cr, a in sorted(ak["apps"].items()):
        ai = g.node(("ak", cr), app_label(a, ak), AK)
        for gr in a["access"]:
            g.edge(g.node(("group", gr), gr, "Groupes Authentik", "round"), ai, "accès")
        for c in chains.get(cr, []):
            if c["consumer"] is None:
                continue
            x = c["consumer"]
            if dex and x is dex["x"]:
                ci = g.node(("dex",), f"Dex {dex['issuer']}", "Dex (courtier)", "hex")
                g.edge(ai, ci, "connecteur OIDC")
            elif x is argo["doc"]:
                ci = g.node(("argodex",), "Dex d'Argo CD", "Argo CD", "hex")
                g.edge(ai, ci, "connecteur OIDC")
            else:
                ci = g.node(("c", x["app"], x["ns"], ref(x["doc"])), consumer_label(x), f"ns {x['ns']}")
                g.edge(ai, ci, "client OIDC", "==>" if cr in step_up else "-->")
    for f in fwd:
        ri = g.node(("route", f["host"]), f"{f['host']}<br/>IngressRoute {f['route']['ns']}/{f['route']['doc']['metadata']['name']}", "Traefik forwardAuth", "para")
        for cr in f["apps"]:
            g.edge(g.node(("ak", cr), app_label(ak["apps"][cr], ak), AK), ri, "forwardAuth", "==>" if cr in step_up else "-->")
    if dex:
        di = g.node(("dex",), f"Dex {dex['issuer']}", "Dex (courtier)", "hex")
        for cl in dex["clients"]:
            ci = g.node(("dexclient", cl["id"]), f"client {cl['id']}", "Dex (courtier)")
            g.edge(di, ci, "")
        for u in dex_users:
            for cl in u["clients"]:
                if u["consumer"] is not None:
                    x = u["consumer"]
                    ti = g.node(("c", x["app"], x["ns"], ref(x["doc"])), consumer_label(x), f"ns {x['ns']}")
                elif u["label"].startswith("apiserver"):
                    continue
                else:
                    ti = g.node(("ext", u["label"]), u["label"].replace("`", ""), "Postes (kubectl)", "stadium")
                g.edge(g.node(("dexclient", cl), f"client {cl}", "Dex (courtier)"), ti, "OIDC")
    ai_ = g.node(("argodex",), "Dex d'Argo CD", "Argo CD", "hex")
    for c in argo["connectors"]:
        iss = (c.get("config") or {}).get("issuer", "")
        if not iss.startswith("$"):
            g.edge(g.node(("ext", iss), f"{c.get('id')}<br/>{iss}", "Émetteurs externes", "para"), ai_, "connecteur OIDC")
    for c in api["contexts"]:
        if dex and c["issuer"].rstrip("/") == dex["issuer"].rstrip("/"):
            continue
        app = next((cr for cr, a in ak["apps"].items() if c["issuer"].rstrip("/").endswith(f"/application/o/{a['slug']}")), None)
        if app:
            g.edge(g.node(("ak", app), app_label(ak["apps"][app], ak), AK),
                   g.node(("ext", f"kubeconfig `{c['context']}`"), f"kubeconfig {c['context']}", "Postes (kubectl)", "stadium"),
                   "OIDC", "==>" if app in step_up else "-->")
    for j in api["jwts"]:
        ji = g.node(("jwt", str(j["i"])), jwt_label(j), "kube-apiserver", "hex")
        kind, src = jsrc[j["i"]]
        if kind == "authentik":
            g.edge(g.node(("ak", src), app_label(ak["apps"][src], ak), AK), ji, "jeton validé", "==>" if src in step_up else "-->")
        elif kind == "dex":
            g.edge(g.node(("dexclient", j["audience"]), f"client {j['audience']}", "Dex (courtier)"), ji, "jeton validé")
        for b in rbs:
            s = b["subject"]
            prefix = j["group_prefix"] if s["kind"] == "Group" else j["user_prefix"]
            if prefix and s["name"].startswith(prefix) and (s["kind"] != "Group" or group_reach(j, s["name"][len(prefix):])):
                bi = g.node(("rb", b["x"]["doc"]["metadata"]["name"]), f"{b['x']['doc']['kind']} {b['x']['doc']['metadata']['name']}<br/>→ {b['role']['name']}", "RBAC Kubernetes")
                g.edge(ji, bi, s["name"])

    # ── index ──
    rows = []
    for cr, a in sorted(ak["apps"].items()):
        p = a["provider"]
        cons = sorted({ref(c["consumer"]["doc"]) + f" ({c['consumer']['ns']})" for c in chains.get(cr, []) if c["consumer"]})
        cons += [f"IngressRoute {f['route']['ns']}/{f['route']['doc']['metadata']['name']}" for f in fwd if cr in f["apps"]]
        cons += offcluster.get(cr, [])
        rows.append([f"[`{a['slug']}`]({DOCS}/applications#{a['slug']})", a["kind"] + (" public" if p.get("clientType") == "public" else ""),
                     ", ".join(f"`{x}`" for x in a["access"]) or "—", code(p.get("authorizationFlow")),
                     "<br/>".join(cons) or "aucun rendu"])
    skipped_md = "\n".join(f"- `{c}` ({a}) : {why}" for c, a, why in skipped) or "- aucun"
    body = f"""La chaîne d'authentification du cluster, tirée du rendu Helm des applications Argo CD (comme [les flux réseau](/docs/security/network-flows)), des CRs de l'opérateur `weebo-authentik`, de la configuration Pulumi de l'apiserver et d'Argo CD, et du kubeconfig du dépôt.

Fournisseur d'identité : Authentik (`{ak['instance'].get('url', '?')}`), géré par CRs dans `2.argo/helm/auth/sub`. Tout le reste s'y raccroche, directement ou par un Dex.

- [Applications Authentik]({DOCS}/applications) : chaque client, ses consommateurs et la façon dont le secret leur parvient.
- [Groupes et accès]({DOCS}/groupes) : qui ouvre quoi, et ce que chaque groupe donne en aval.
- [Flux Authentik]({DOCS}/flux) : les flux, les blueprints, le second facteur.
- [Kubernetes]({DOCS}/kubernetes) : de `kubectl` aux RoleBindings.
- [Argo CD]({DOCS}/argocd) : connecteurs, rôles, projets et ce que chacun permet.

## Légende

{LEGEND}

## Chaîne globale

```mermaid
{g.render()}
```

## Applications

{table(["Application", "Type", "Accès", "Flux d'autorisation", "Consommateurs"], rows)}

## Charts non rendus

{skipped_md}
"""
    (OUT / "index.mdx").write_text(page("Authentification", "La chaîne d'authentification du cluster, générée depuis les charts", body))

    # ── applications ──
    secs = []
    for cr, a in sorted(ak["apps"].items(), key=lambda kv: kv[1]["slug"]):
        p = a["provider"]
        c = Chart()
        ai = c.node(("ak", cr), app_label(a, ak), AK)
        for gr in a["access"]:
            for u in members(ak, gr):
                c.edge(c.node(("user", u), f"👤 {u}", "Utilisateurs", "stadium"), c.node(("group", gr), gr, "Groupes Authentik", "round"), "membre (direct ou hérité)")
            c.edge(c.node(("group", gr), gr, "Groupes Authentik", "round"), ai, "accès")
        flow = p.get("authorizationFlow")
        if flow:
            c.edge(ai, c.node(("flow", flow), f"flux {flow}", "Flux", "para"), "autorisation", "==>" if cr in step_up else "-->")
        for ch in chains.get(cr, []):
            x = ch["consumer"]
            if x is None:
                c.edge(ai, c.node(("none", ch["via"]), "aucun lecteur rendu", "Consommateurs", "para"), ch["via"].replace("`", ""))
                continue
            lab = "Dex " + dex["issuer"] if dex and x is dex["x"] else ("Dex d'Argo CD" if x is argo["doc"] else consumer_label(x))
            c.edge(ai, c.node(("c", x["app"], x["ns"], ref(x["doc"])), lab, f"ns {x['ns']}"), ch["via"].replace("`", ""))
        for f in fwd:
            if cr in f["apps"]:
                c.edge(ai, c.node(("route", f["host"]), f"{f['host']}<br/>IngressRoute {f['route']['ns']}/{f['route']['doc']['metadata']['name']}", "Traefik", "para"), f"forwardAuth {f['middleware']}")
        props = [["Slug", code(a["slug"])], ["CR", code(cr)], ["Fournisseur", a["kind"]]]
        if a["kind"] == "oauth2":
            issuer = f"{ak['instance'].get('url', '')}/application/o/{a['slug']}/"
            props += [["Émetteur", code(issuer)], ["Client", f"{code(p.get('clientId'))} ({p.get('clientType', 'confidential')})"],
                      ["Grants", ", ".join(code(x) for x in p.get("grantTypes") or []) or "—"],
                      ["Durée du jeton d'accès", code(p.get("accessTokenValidity", "défaut"))],
                      ["Scopes / mappings", "<br/>".join(code(x) for x in p.get("propertyMappings") or [])],
                      ["Redirections", "<br/>".join(f"{code(r['url'])} ({r.get('matchingMode', 'strict')})" for r in p.get("allowedRedirectUris") or [])],
                      ["Clé de signature", code(p.get("signingKey"))]]
        else:
            props += [["Hôte externe", code(p.get("externalHost"))], ["Hôte interne", code(p.get("internalHost"))]]
        props += [["Flux d'autorisation", code(flow) + (" (second facteur)" if cr in step_up else "")],
                  ["Flux d'invalidation", code(p.get("invalidationFlow"))],
                  ["Accès", ", ".join(code(x) for x in a["access"]) or "aucune politique : ouvert à tout utilisateur"],
                  ["Utilisateurs autorisés", ", ".join(code(u) for gr in a["access"] for u in members(ak, gr)) or "—"],
                  ["Secret écrit dans", ", ".join(code(t.get("path")) for t in a["secretTargets"]) or "—"]]
        consumers = [[code(ch["consumer"]["app"]) if ch["consumer"] else "—",
                      code(f"{ch['consumer']['ns']}/{ref(ch['consumer']['doc'])}") if ch["consumer"] else "aucun lecteur rendu",
                      ch["via"]] for ch in chains.get(cr, [])]
        consumers += [["hors Argo CD", lab, "issuer de l'application"] for lab in offcluster.get(cr, [])]
        consumers += [["—", code(f"{f['route']['ns']}/IngressRoute/{f['route']['doc']['metadata']['name']}"), f"forwardAuth `{f['middleware']}` sur `{f['host']}`"]
                      for f in fwd if cr in f["apps"]]
        cons_md = table(["App Argo CD", "Objet", "Chemin du secret"], consumers) if consumers else "Aucun consommateur trouvé dans le rendu."
        secs.append(f"""## {a['slug']}

```mermaid
{c.render()}
```

{table(["Propriété", "Valeur"], props)}

### Consommateurs

{cons_md}
""")
    body = "Une section par application Authentik (`AuthentikApplication`), avec qui y a accès, par quel flux, et qui consomme son client.\n\n## Légende\n\n" + LEGEND + "\n\n" + "\n".join(secs)
    (OUT / "applications.mdx").write_text(page("Applications Authentik", "Chaque client Authentik et ses consommateurs", body))

    # ── groupes ──
    c = Chart("TB")
    for name, spec in ak["groups"].items():
        gi = c.node(("group", name), name + (" (superuser)" if spec.get("isSuperuser") else ""), None, "round")
        if spec.get("parentRef"):
            c.edge(gi, c.node(("group", spec["parentRef"]), spec["parentRef"], None, "round"), "inclus dans", "-.->")
    for u, spec in ak["users"].items():
        for gr in spec.get("groupRefs") or []:
            c.edge(c.node(("user", u), f"👤 {u}", None, "stadium"), c.node(("group", gr), gr, None, "round"), "membre")
    apps_sorted = sorted(ak["apps"].values(), key=lambda a: a["slug"])
    matrix = []
    for name in ak["groups"]:
        below = [n for n in ak["groups"] if name in ancestors(ak["groups"], n)]
        row = [code(name)]
        for a in apps_sorted:
            if name in a["access"]:
                row.append("✅")
            elif any(b in a["access"] for b in below if b != name):
                row.append("—")
            elif any(x in a["access"] for x in ancestors(ak["groups"], name)[1:]):
                row.append("✅ hérité")
            else:
                row.append("—")
        matrix.append(row)
    for u in ak["users"]:
        eff = effective_groups(ak, u)
        matrix.append([f"👤 {code(u)}"] + ["✅" if any(x in a["access"] for x in eff) else "—" for a in apps_sorted])
    users_rows = [[code(u), s.get("name", ""), code(s.get("email")), ", ".join(code(x) for x in s.get("groupRefs") or []),
                   ", ".join(code(x) for x in effective_groups(ak, u)), "oui" if s.get("isActive", True) else "non"]
                  for u, s in ak["users"].items()]
    vis = argo_visibility(docs, ak, argo)
    vis_rows = [[code(u), what, how] for u in ak["users"] for what, how in vis.get(u) or [("rien", "aucun rôle")]]
    down = []
    for gname in ak["groups"]:
        for x, path in mentions.get(gname, []):
            down.append([code(gname), code(x["app"]), code(f"{x['ns']}/{ref(x['doc'])}"), code(path.lstrip("."))])
    claims = [[code(m["name"]), code(m.get("scopeName")), m.get("description", ""), mdcode(m.get("expression", ""))]
              for m in ak["mappings"].values()]
    argo_rows = [[code(gr), code(role)] for gr, role in argo["roles"]]
    body = f"""Les groupes et utilisateurs déclarés dans `2.argo/helm/auth/sub` (`AuthentikGroup`, `AuthentikUser`), ce qu'ils ouvrent dans Authentik, et ce qu'un groupe donne ensuite dans chaque système qui lit la claim `groups`.

## Hiérarchie

Un membre d'un groupe enfant est aussi membre de ses parents pour Authentik : une politique sur `weebo_user` laisse passer `weebo_moderator` et `weebo_admin`.

```mermaid
{c.render()}
```

## Utilisateurs

{table(["Utilisateur", "Nom", "Email", "Groupes directs", "Groupes effectifs", "Actif"], users_rows)}

## Applications Argo CD visibles

Ce que chaque utilisateur voit une fois connecté à Argo CD (qui exige d'abord l'accès à l'application Authentik `argo`) : les rôles globaux de `policy.csv` (`1.pulu-conf`) par groupe, et les rôles des AppProjects par groupe ou par email (scopes RBAC : `{argo['scopes']}`). La politique par défaut d'Argo CD ne donne rien.

Ces rôles, comme les RoleBindings `labsso:<email>` de l'apiserver, font confiance à la claim `email` : ils supposent qu'un utilisateur ne peut pas changer son email dans Authentik (System › Settings, « Allow users to change email » désactivé).

{table(["Utilisateur", "Applications", "Par"], vis_rows)}

## Accès aux applications

« ✅ » : la politique d'accès de l'application vise ce groupe ; « ✅ hérité » : elle vise un parent, que ce groupe satisfait.

{table(["", *[a["slug"] for a in apps_sorted]], matrix)}

## Claims émises

Les mappings de scope maison (`AuthentikScopeMapping`) : ce qu'une application qui les demande reçoit dans le jeton.

{table(["Mapping", "Scope", "Description", "Expression"], claims)}

## Ce que les groupes donnent en aval

Chaque endroit du rendu (et de la configuration Pulumi d'Argo CD) qui nomme un groupe Authentik : une autorisation accordée au groupe par le système qui consomme la claim `groups`.

{table(["Groupe", "App Argo CD", "Objet", "Champ"], down) if down else "Aucune."}

### Argo CD (`1.pulu-conf`, `policy.csv`)

Scopes lus pour les groupes : `{argo['scopes']}`.

{table(["Groupe", "Rôle Argo CD"], argo_rows)}
"""
    (OUT / "groupes.mdx").write_text(page("Groupes et accès", "Les groupes Authentik, ce qu'ils ouvrent et ce qu'ils donnent en aval", body))

    # ── flux ──
    c = Chart()
    used = defaultdict(list)
    for cr, a in ak["apps"].items():
        for k in ("authorizationFlow", "invalidationFlow"):
            if a["provider"].get(k):
                used[a["provider"][k]].append((a["slug"], k))
    for slug, lst in used.items():
        f = ak["flows"].get(slug, {})
        fi = c.node(("flow", slug), f"{slug}<br/>{f.get('designation', 'introuvable')}", "Flux", "para")
        for app, k in lst:
            if k == "authorizationFlow":
                c.edge(c.node(("ak", app), app, AK), fi, "autorisation", "==>" if f.get("stages") else "-->")
        for st in f.get("stages") or []:
            attrs = st.get("attrs") or {}
            lab = (st.get("identifiers") or {}).get("name", st["model"])
            detail = ", ".join(attrs.get("device_classes") or [])
            c.edge(fi, c.node(("stage", lab), f"étape {lab}<br/>{st['model'].split('.')[-1]}<br/>{detail}", "Étapes", "hex"), "étape")
    brand = ak["brand"]
    brand_rows = [[code(k), code(brand.get(k))] for k in ("flowAuthentication", "flowInvalidation", "flowRecovery", "flowUnenrollment", "flowUserSettings") if k in brand]
    flow_rows = [[code(s), f.get("designation", ""), code(f.get("authentication")), f.get("title", ""), f.get("source", ""),
                  ", ".join(code(a) for a, _ in used.get(s, [])) or "—"] for s, f in sorted(ak["flows"].items())]
    referenced = set(used) | {brand[k] for k in ("flowAuthentication", "flowInvalidation", "flowRecovery", "flowUnenrollment", "flowUserSettings") if brand.get(k)}
    missing = sorted(s for s in referenced if s not in ak["flows"])
    bp_md = []
    for bp in ak["blueprints"]:
        ent = [[code(e.get("model")), code(e.get("id")), code(json.dumps(e.get("identifiers") or {}, ensure_ascii=False))] for e in bp["entries"]]
        bp_md.append(f"### {bp['name']}\n\n{bp['description']} (CR `{bp['cr']}`)\n\n{table(['Modèle', 'Id', 'Identifiants'], ent)}\n")
    stage_rows = []
    for s, f in ak["flows"].items():
        for st in f.get("stages") or []:
            at = st.get("attrs") or {}
            stage_rows.append([code(s), code((st.get("identifiers") or {}).get("name")), code(st["model"]),
                               "<br/>".join(f"{k}: {code(json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v)}" for k, v in at.items())])
    body = f"""Les flux Authentik : ceux qu'adoptent les `AuthentikFlow`, ceux que créent les blueprints (`AuthentikBlueprint`), et les applications qui s'en servent.

## Applications → flux d'autorisation

Une flèche épaisse mène à un flux qui exige un second facteur.

```mermaid
{c.render()}
```

## Flux

{table(["Slug", "Désignation", "Authentification", "Titre", "Source", "Utilisé par"], flow_rows)}

{"**Flux référencés mais absents du rendu** (fournis par Authentik lui-même, ou à créer) : " + ", ".join(code(m) for m in missing) if missing else ""}

## Étapes déclarées

{table(["Flux", "Étape", "Modèle", "Attributs"], stage_rows) if stage_rows else "Aucune."}

## Flux de la marque

La marque `{brand.get('domain', '?')}` (`AuthentikBrand`) :

{table(["Champ", "Flux"], brand_rows) if brand_rows else "Aucun flux fixé."}

## Blueprints

{chr(10).join(bp_md) or "Aucun."}
"""
    (OUT / "flux.mdx").write_text(page("Flux Authentik", "Les flux d'authentification et d'autorisation Authentik", body))

    # ── kubernetes ──
    c = Chart()
    for ctx in api["contexts"]:
        ki = c.node(("ext", ctx["context"]), f"kubeconfig {ctx['context']}<br/>client {ctx['client']}", "Poste", "stadium")
        if dex and ctx["issuer"].rstrip("/") == dex["issuer"].rstrip("/"):
            di = c.node(("dex", ctx["client"]), f"Dex {dex['issuer']}<br/>client {ctx['client']}", "Dex", "hex")
            c.edge(ki, di, "connexion")
            if dex_app:
                c.edge(di, c.node(("ak", dex_app), app_label(ak["apps"][dex_app], ak), AK), "connecteur")
        else:
            app = next((cr for cr, a in ak["apps"].items() if ctx["issuer"].rstrip("/").endswith(f"/application/o/{a['slug']}")), None)
            if app:
                c.edge(ki, c.node(("ak", app), app_label(ak["apps"][app], ak), AK), "connexion", "==>" if app in step_up else "-->")
    for j in api["jwts"]:
        ji = c.node(("jwt", str(j["i"])), jwt_label(j), "kube-apiserver", "hex")
        kind, src = jsrc[j["i"]]
        if kind == "authentik":
            c.edge(c.node(("ak", src), app_label(ak["apps"][src], ak), AK), ji, "jeton", "==>" if src in step_up else "-->")
            for gr in ak["apps"][src]["access"]:
                c.edge(c.node(("group", gr), gr, "Groupes Authentik", "round"), c.node(("ak", src), "", AK), "accès")
        elif kind == "dex":
            c.edge(c.node(("dex", j["audience"]), f"Dex {dex['issuer']}<br/>client {j['audience']}", "Dex", "hex"), ji, "jeton")
            if src:
                for gr in ak["apps"][src]["access"]:
                    c.edge(c.node(("group", gr), gr, "Groupes Authentik", "round"), c.node(("ak", src), app_label(ak["apps"][src], ak), AK), "accès")
        for b in rbs:
            s = b["subject"]
            prefix = j["group_prefix"] if s["kind"] == "Group" else j["user_prefix"]
            if prefix and s["name"].startswith(prefix) and (s["kind"] != "Group" or group_reach(j, s["name"][len(prefix):])):
                c.edge(ji, c.node(("rb", b["x"]["doc"]["metadata"]["name"]), f"{b['x']['doc']['kind']} {b['x']['doc']['metadata']['name']}<br/>→ {b['role']['kind']} {b['role']['name']}", "RBAC"), s["name"])
    jwt_rows = []
    for j in api["jwts"]:
        kind, src = jsrc[j["i"]]
        behind = {"authentik": f"Authentik `{ak['apps'][src]['slug']}`" if src else "", "dex": f"Dex, connecteur vers Authentik `{ak['apps'][src]['slug']}`" if src else "Dex",
                  "other": "?"}[kind]
        gmap = j["groups"].get("expression") or f"claim `{j['groups']['claim']}`, préfixe `{j['groups']['prefix']}`"
        umap = j["username"].get("expression") or f"claim `{j['username']['claim']}`"
        jwt_rows.append([f"jwt[{j['i']}]", code(j["issuer"]), code(j["audience"]), j["origin"], behind,
                         mdcode(umap), gmap if "expression" not in j["groups"] else mdcode(gmap),
                         ", ".join(code(x) for x in j["excluded"]) or "—"])
    rb_rows = []
    for b in rbs:
        s = b["subject"]
        via = []
        for j in api["jwts"]:
            prefix = j["group_prefix"] if s["kind"] == "Group" else j["user_prefix"]
            if prefix and s["name"].startswith(prefix) and (s["kind"] != "Group" or group_reach(j, s["name"][len(prefix):])):
                kind, src = jsrc[j["i"]]
                need = ak["apps"][src]["access"] if src else []
                via.append(f"jwt[{j['i']}]" + (f" (accès Authentik : {', '.join(code(x) for x in need)})" if need else ""))
        rb_rows.append([code(f"{b['x']['doc']['kind']}/{b['x']['doc']['metadata']['name']}"), code(b["x"]["ns"]) if b["x"]["doc"]["kind"] == "RoleBinding" else "cluster",
                        code(f"{b['role']['kind']}/{b['role']['name']}"), f"{s['kind']} {code(s['name'])}", "<br/>".join(via) or "**aucun émetteur ne produit ce nom**",
                        code(b["x"]["app"])])
    ctx_rows = [[code(x["context"]), code(x["issuer"]), code(x["client"]), code(x["scopes"])] for x in api["contexts"]]
    dex_rows = [[code(cl["id"]), cl.get("name", ""), "<br/>".join(code(u) for u in cl.get("redirectURIs") or []), ", ".join(code(t) for t in cl.get("trustedPeers") or []) or "—"]
                for cl in (dex or {}).get("clients", [])]
    rules = "\n".join(f"- {code(r)}" for r in api["rules"])
    body = f"""De `kubectl` aux droits : les deux émetteurs que l'apiserver accepte (`AuthenticationConfiguration`, écrite par `1.pulu-init/main.go`), d'où viennent leurs jetons, et les (Cluster)RoleBindings qu'atteignent les noms qu'ils produisent.

```mermaid
{c.render()}
```

## Émetteurs JWT de l'apiserver

{table(["", "Émetteur", "Audience", "Origine", "Derrière", "Nom d'utilisateur", "Groupes", "Groupes retirés"], jwt_rows)}

Règles communes, sur les claims puis sur l'utilisateur obtenu :

{rules}

## Contextes du kubeconfig

`0.config/kubeconfig.oidc-template.yaml` :

{table(["Contexte", "Émetteur", "Client", "Scopes en plus"], ctx_rows)}

## Clients statiques de Dex

{table(["Client", "Nom", "Redirections", "Pairs de confiance"], dex_rows) if dex_rows else "Pas de Dex rendu."}

## RBAC

Les bindings du rendu qui nomment un groupe ou un utilisateur hors `system:`, et l'émetteur capable de produire ce nom.

{table(["Binding", "Portée", "Rôle", "Sujet", "Atteint par", "App Argo CD"], rb_rows) if rb_rows else "Aucun."}
"""
    (OUT / "kubernetes.mdx").write_text(page("Kubernetes", "De kubectl aux RoleBindings : les émetteurs de l'apiserver", body))

    argo_page(docs, ak, argo, chains)

    (OUT / "meta.json").write_text(json.dumps({"title": "Authentification", "pages": ["index", "applications", "groupes", "flux", "kubernetes", "argocd"]}, indent=2) + "\n")
    n_cons = sum(1 for cs in chains.values() for c in cs if c["consumer"])
    print(f"authflow: {len(ak['apps'])} applications, {len(ak['groups'])} groups, {len(ak['users'])} users, "
          f"{n_cons} consumers, {len(api['jwts'])} jwt issuers, {len(rbs)} bindings -> {OUT.relative_to(ROOT)}")
    for c_, a, why in skipped:
        print(f"authflow: skipped {c_} ({a}): {why}", file=sys.stderr)


if __name__ == "__main__":
    main()
