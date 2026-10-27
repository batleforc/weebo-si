#!/usr/bin/env bash
# Loads the plugin into the Traefik the cluster runs and checks the request-id contract
# end to end. Traefik interprets plugins with Yaegi, not the Go compiler: code that passes
# `go test` can still fail to load. Needs docker or podman, helm and curl.
#   ./e2e.sh                 Traefik version from ../../values.yaml
#   TRAEFIK=v3.7.16 ./e2e.sh another one
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
engine=${ENGINE:-$(command -v docker || command -v podman)}
port=${PORT:-18090}
if [ -z "${TRAEFIK:-}" ]; then
  chart=$(awk '/depName=ghcr.io\/traefik\/helm\/traefik/ { getline; print $2; exit }' "$here/../../values.yaml")
  TRAEFIK=$(helm show chart oci://ghcr.io/traefik/helm/traefik --version "$chart" | awk '/^appVersion:/ { print $2 }')
fi
echo "traefik $TRAEFIK"

work=$(mktemp -d)
net="rid-e2e-$$"
cleanup() {
  "$engine" rm -f "$net-traefik" "$net-echo" >/dev/null 2>&1 || true
  "$engine" network rm "$net" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

# The files the chart ships, nothing else (templates/traefik/traefik.yaml).
mkdir -p "$work/plugin"
cp "$here/.traefik.yml" "$here/go.mod" "$here/requestid.go" "$work/plugin/"
# One router per trust setting: nobody trusted, everybody trusted.
cat >"$work/dynamic.yml" <<'EOF'
http:
  middlewares:
    trust-none: { plugin: { requestid: { headerName: X-Request-Id, trustedIPs: [] } } }
    trust-all: { plugin: { requestid: { headerName: X-Request-Id, trustedIPs: ["0.0.0.0/0", "::/0"] } } }
    # Stands in for a backend answering with its own id (RustFS does).
    own-id: { headers: { customResponseHeaders: { X-Request-Id: backend-own-id } } }
  routers:
    untrusted: { rule: "Host(`untrusted.test`)", service: echo, middlewares: [trust-none] }
    trusted: { rule: "Host(`trusted.test`)", service: echo, middlewares: [trust-all] }
    own: { rule: "Host(`own.test`)", service: echo, middlewares: [trust-none, own-id] }
  services:
    echo: { loadBalancer: { servers: [{ url: "http://echo:80" }] } }
EOF

"$engine" network create "$net" >/dev/null
"$engine" run -d --name "$net-echo" --network "$net" --network-alias echo docker.io/traefik/whoami:v1.11 >/dev/null
"$engine" run -d --name "$net-traefik" --network "$net" -p "127.0.0.1:$port:80" \
  -v "$work/plugin:/plugins-local/src/weebo.poc/requestid:ro,Z" -v "$work:/cfg:ro,Z" \
  "docker.io/traefik:$TRAEFIK" \
  --entryPoints.web.address=:80 --providers.file.filename=/cfg/dynamic.yml \
  --experimental.localPlugins.requestid.moduleName=weebo.poc/requestid --log.level=INFO >/dev/null

for _ in $(seq 30); do
  curl -sf -o /dev/null -H 'Host: untrusted.test' "http://127.0.0.1:$port/" && break
  sleep 1
done
if ! "$engine" logs "$net-traefik" 2>&1 | grep -q 'Plugins loaded'; then
  "$engine" logs "$net-traefik" 2>&1 | tail -20
  echo "FAIL: the plugin did not load" >&2
  exit 1
fi

fail=0
uuid='^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
# check <name> <host> <expected: uuid|literal> [sent id]
check() {
  local name=$1 host=$2 want=$3
  local args=(-s -D "$work/headers" -H "Host: $host")
  [ $# -ge 4 ] && args+=(-H "X-Request-Id: $4")
  local body backend response
  body=$(curl "${args[@]}" "http://127.0.0.1:$port/")
  backend=$(printf '%s\n' "$body" | awk -F': ' 'tolower($1) == "x-request-id" { print $2 }' | tr -d '\r')
  response=$(awk -F': ' 'tolower($1) == "x-request-id" { print $2 }' "$work/headers" | tr -d '\r')
  local ok=1
  [ "$(grep -ci '^x-request-id:' "$work/headers")" = 1 ] || ok=0
  [ "$backend" = "$response" ] || ok=0
  if [ "$want" = uuid ]; then [[ $backend =~ $uuid ]] || ok=0; else [ "$backend" = "$want" ] || ok=0; fi
  if [ $ok = 1 ]; then echo "ok    $name"; else echo "FAIL  $name: backend '$backend', response '$response'"; fail=1; fi
}

check "no id: one is generated" untrusted.test uuid
check "untrusted client cannot choose it" untrusted.test uuid i-picked-this
check "trusted proxy keeps its id" trusted.test edge-7f3a:01 edge-7f3a:01
check "trusted but malformed is replaced" trusted.test uuid '<script>'
check "trusted but too long is replaced" trusted.test uuid "$(printf 'a%.0s' $(seq 129))"

# The backend's own id is the one the client gets, alone; the backend still saw ours.
body=$(curl -s -D "$work/headers" -H 'Host: own.test' "http://127.0.0.1:$port/")
sent=$(printf '%s\n' "$body" | awk -F': ' 'tolower($1) == "x-request-id" { print $2 }' | tr -d '\r')
got=$(awk -F': ' 'tolower($1) == "x-request-id" { print $2 }' "$work/headers" | tr -d '\r' | paste -sd,)
if [ "$got" = backend-own-id ] && [[ $sent =~ $uuid ]]; then echo "ok    backend's own id is kept"
else echo "FAIL  backend's own id is kept: response '$got', backend saw '$sent'"; fail=1; fi

# A WebSocket upgrade goes through the plugin's response writer (Hijack).
status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 -H 'Host: untrusted.test' \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H "Sec-WebSocket-Key: $(head -c 16 /dev/urandom | base64)" "http://127.0.0.1:$port/echo" || true)
if [ "$status" = 101 ]; then echo "ok    websocket upgrade"; else echo "FAIL  websocket upgrade: HTTP $status"; fail=1; fi
exit $fail
