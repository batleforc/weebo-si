#!/usr/bin/env bash
# Workspace témoin (durcissement-workspaces.md, phase 1) : démarre un vrai
# DevWorkspace dans $NS, y rejoue les interdits, et sort non nul si une
# attaque réussit. À lancer après chaque changement du durcissement, ou par
# un cron si on le veut.
#
#   task hardening:witness            # démarre, teste, arrête
#   KEEP=1 task hardening:witness     # laisse le workspace démarré
#
# Chaque ligne : « W-xx | PASS|FAIL | attendu (obtenu) ». Rien n'est écrit
# hors de $NS ; les tests d'admission sont des dry-run serveur.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export KUBECONFIG=${KUBECONFIG:-$ROOT/0.config/kubeconfig.yaml}
NS=${NS:-dev-ws-batleforc-test}
DW=${DW:-hardening-witness}
PARENT=${PARENT:-https://raw.githubusercontent.com/batleforc/WeeboDevImage/refs/heads/main/che-min-mise/devfile.yaml}
k() { kubectl "$@"; }

FAILS=0
check() { # id description expected got
  local status=PASS
  [ "$3" = "$4" ] || { status=FAIL; FAILS=$((FAILS + 1)); }
  printf '| %s | %s | %s | %s (%s) |\n' "$1" "$status" "$2" "$3" "$4"
}

k apply -f - >/dev/null <<EOF
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: $DW
  namespace: $NS
spec:
  started: true
  routingClass: che
  template:
    attributes:
      weebo.io/platform-contract: 1
      controller.devfile.io/storage-type: ephemeral
    parent:
      uri: $PARENT
EOF
k -n "$NS" patch dw "$DW" --type merge -p '{"spec":{"started":true}}' >/dev/null
k -n "$NS" wait dw "$DW" --for=jsonpath='{.status.phase}'=Running --timeout=600s >/dev/null
POD=$(k -n "$NS" get pods -l controller.devfile.io/devworkspace_name="$DW" -o name | head -1)
# Container named by the parent devfile; the first non-gateway one.
CTR=$(k -n "$NS" get "$POD" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n' | grep -v che-gateway | head -1)
x() { k -n "$NS" exec "$POD" -c "$CTR" -- sh -c "$1" 2>/dev/null || true; }

echo "| Test | Résultat | Interdit | attendu (obtenu) |"
echo "|---|---|---|---|"

# Identité (RFC 0018) : 1234 partout, user namespace propre, aucune capability.
check W-01 "uid/gid/groupes" "1234 1234 1234" "$(x 'echo $(id -u) $(id -g) $(id -G)')"
check W-02 "root du pod = root du nœud" "no" "$(x 'awk "NR==1{print (\$2==0)?\"yes\":\"no\"}" /proc/self/uid_map')"
check W-03 "capabilities effectives" "0000000000000000" "$(x 'awk "/^CapEff/{print \$2}" /proc/self/status')"
check W-04 "no_new_privs" "1" "$(x 'awk "/^NoNewPrivs/{print \$2}" /proc/self/status')"

# KubeArmor (Block) : token, shadow, /usr/bin.
check W-05 "lire le token du ServiceAccount" "denied" "$(x 'cat /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null 2>&1 && echo read || echo denied')"
check W-06 "lire /etc/shadow" "denied" "$(x 'cat /etc/shadow >/dev/null 2>&1 && echo read || echo denied')"
check W-07 "écrire dans /usr/bin" "denied" "$(x 'touch /usr/bin/.witness 2>/dev/null && echo written || echo denied')"
# Identity files root:root 0644 in the image (WeeboDevImage #216): denied by
# mode alone, whatever the groups pod-identity hands out.
check W-18 "modifier /etc/passwd, group, subuid, subgid" "644:0:0 644:0:0 644:0:0 644:0:0 denied" \
  "$(x 'echo $(stat -c %a:%u:%g /etc/passwd /etc/group /etc/subuid /etc/subgid) $(for f in /etc/passwd /etc/group /etc/subuid /etc/subgid; do [ -w $f ] && echo $f; done | grep -q . && echo writable || echo denied)')"

# Réseau (Cilium) : DNS restreint, Traefik filtré, fronting refusé, pas d'Internet.
check W-08 "résoudre un domaine hors profil" "refused" "$(x 'getent hosts example.com >/dev/null && echo resolved || echo refused')"
check W-09 "résoudre un domaine du profil" "resolved" "$(x 'getent hosts github.com >/dev/null && echo resolved || echo refused')"
check W-10 "joindre Argo CD" "000" "$(x 'curl -s -o /dev/null -w %{http_code} --max-time 6 https://argo.weebo.poc/')"
check W-11 "joindre OpenBao" "000" "$(x 'curl -s -o /dev/null -w %{http_code} --max-time 6 https://vault.weebo.poc/')"
check W-12 "domain fronting pkg -> argo" "421" "$(x 'curl -s -o /dev/null -w %{http_code} --max-time 6 -H "Host: argo.weebo.poc" https://pkg.weebo.poc/')"
check W-13 "Internet par IP" "000" "$(x 'curl -sk -o /dev/null -w %{http_code} --max-time 6 https://1.1.1.1/')"
check W-14 "BatleHub joignable (témoin du témoin)" "200" "$(x 'curl -s -o /dev/null -w %{http_code} --max-time 10 https://pkg.weebo.poc/')"

# Admission (PodSecurity restricted, pod-identity), en dry-run serveur.
# `|| true` inside: kubectl exits 1 on a refusal, and pipefail would hide the
# message from the test.
img=registry.pkg.weebo.poc/hub/library/busybox
priv=$(k -n "$NS" run witness-priv --image=$img --restart=Never --dry-run=server -o name \
  --overrides='{"spec":{"containers":[{"name":"c","image":"'$img'","securityContext":{"privileged":true}}]}}' 2>&1 || true)
check W-15 "pod privilégié (PodSecurity)" "refused" "$(grep -q forbidden <<<"$priv" && echo refused || echo admitted)"
# A pod PodSecurity admits, asking for the node's user namespace: pod-identity
# must hand it its own (hostUsers false) and uid 1234.
safe='"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}'
ctr='"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}'
hu=$(k -n "$NS" run witness-hu --image=$img --restart=Never --dry-run=server \
  -o jsonpath='{.spec.hostUsers} {.spec.securityContext.runAsUser}' \
  --overrides='{"spec":{"hostUsers":true,'"$safe"',"containers":[{"name":"c","image":"'$img'",'"$ctr"'}]}}' 2>&1 || true)
check W-16 "pod dans le user namespace du nœud (pod-identity)" "false 1234" "$hu"
# Not a forbidden act but the CA the user kubeconfig falls back on (WeeboDevImage
# #217): ca.crt sits in the blocked token directory, so kubectl and kubedock
# trust che-operator's bundle, which must hold the cluster CA.
ca_line=$(k -n "$NS" get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' | sed -n 2p)
: "${ca_line:=no cluster CA read}"  # an empty pattern would match any bundle
check W-19 "CA du cluster dans le bundle Che (kubeconfig utilisateur)" "present" \
  "$(x "grep -qsF '$ca_line' /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /public-certs/tls-ca-bundle.pem && echo present || echo missing")"
check W-17 "quota du namespace" "weebo-quota" "$(k -n "$NS" get resourcequota weebo-quota -o name 2>/dev/null | cut -d/ -f2)"

[ -n "${KEEP:-}" ] || k -n "$NS" patch dw "$DW" --type merge -p '{"spec":{"started":false}}' >/dev/null
echo
if [ "$FAILS" -gt 0 ]; then echo "$FAILS interdit(s) franchi(s)"; exit 1; fi
echo "tous les interdits tiennent"
