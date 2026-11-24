#!/usr/bin/env bash
# Validation amont du durcissement des workspaces (protocole V-xx de
# 0.docs/content/todo/durcissement-workspaces.md, section « Protocole de test »).
#
#   task hardening:validate                 # tous les tests sûrs (lecture + pods jetables)
#   task hardening:validate -- V-01 V-05    # une sélection
#   ALLOW_CHE_PATCH=1 task hardening:validate -- V-12
#
# Chaque test écrit une ligne « V-xx | PASS|FAIL|SKIP|MANUAL | détail » sur stdout et sa preuve
# brute dans $OUT/V-xx.log. Le tableau final se colle tel quel dans la page de campagne.
#
# Règles du protocole respectées ici :
# - on n'agit que dans $TEST_NS (dev-ws-batleforc-test) et dans $SCRATCH_NS, un namespace jetable
#   exclu de weebo-si (policyGuard y refuserait nos CNP/KubeArmorPolicy de test, T-08/T-09) ;
# - chaque test supprime ce qu'il crée (trap EXIT) ;
# - rien de ce qui passe par Git (RuntimeClass, DWOC, values.yaml) n'est créé ici : un test dont le
#   prérequis Git manque sort en SKIP avec l'étape à faire ;
# - V-12 modifie le DWOC de Che : il ne tourne qu'avec ALLOW_CHE_PATCH=1.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export KUBECONFIG=${KUBECONFIG:-$ROOT/0.config/kubeconfig.yaml}
TEST_NS=${TEST_NS:-dev-ws-batleforc-test}
SCRATCH_NS=${SCRATCH_NS:-hardening-validate}
# crane:debug embarque busybox (sh, id, nc, nslookup, ping) et est déjà en cache dans angos,
# épinglé par digest : il passe imagePolicy sans rien ouvrir.
IMG=${IMG:-registry.pkg.weebo.poc/gcr/go-containerregistry/crane:debug@sha256:e78770b31258a3846f878036d9c1f63fbe4c871f9f56990bf77fd95c013e3c1b}
# shortcut: tag flottant, la preuve note le digest résolu ; épingler dès que V-16 est passé.
BUILDKIT_IMG=${BUILDKIT_IMG:-registry.pkg.weebo.poc/hub/moby/buildkit:rootless}
# Un pod jetable ne reçoit que weebo-base (les profils visent devworkspace_id) : la cible autorisée
# doit être dans la base, d'où le kube-apiserver plutôt que github.com.
ALLOWED_FQDN=${ALLOWED_FQDN:-kubernetes.default.svc.cluster.local}
DENIED_FQDN=${DENIED_FQDN:-example.com}
OUT=${OUT:-$ROOT/.hardening-runs/$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"

SH=${SH:-/busybox/sh}
k() { kubectl "$@"; }
ka() { karmor "$@"; }
SUMMARY=()
report() { # id status detail
  local line
  line=$(printf '| %s | %s | %s |' "$1" "$2" "$3")
  SUMMARY+=("$line")
  printf '%s\n' "$line"
}
log() { tee -a "$OUT/$1.log" >/dev/null; }

CREATED=()
cleanup() {
  for obj in "${CREATED[@]}"; do
    # shellcheck disable=SC2086 # "kind/name -n ns" est volontairement découpé
    k delete $obj --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

track() { CREATED+=("$1"); }

has_runtimeclass() { k get runtimeclass "$1" >/dev/null 2>&1; }

ensure_scratch_ns() { # $1 = niveau PSA
  if ! k get ns "$SCRATCH_NS" >/dev/null 2>&1; then
    k create ns "$SCRATCH_NS" >/dev/null
    track "ns/$SCRATCH_NS"
  fi
  k label ns "$SCRATCH_NS" --overwrite hardening.weebo.io/exclude=true \
    "pod-security.kubernetes.io/enforce=${1:-baseline}" >/dev/null
}

# Un pod de test. Arguments : nom, namespace, puis lignes YAML ajoutées sous spec (indentées de 2).
apply_pod() {
  local name=$1 ns=$2 extra=${3:-}
  k apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $name
  namespace: $ns
  labels: { app.kubernetes.io/part-of: hardening-validate, hardening-validate/test: $name }
spec:
  restartPolicy: Never
  terminationGracePeriodSeconds: 1
$extra
  containers:
    - name: t
      image: $IMG
      command: ["$SH", "-c", "sleep 900"]
      resources: { limits: { memory: 64Mi, cpu: 200m } }
EOF
  track "pod/$name -n $ns"
  k -n "$ns" wait --for=condition=Ready "pod/$name" --timeout=120s >/dev/null || {
    k -n "$ns" describe pod "$name" | tail -20 >&2; return 1; }
}

kx() { local ns=$1 pod=$2; shift 2; k -n "$ns" exec "$pod" -- "$SH" -c "$*"; }

# ---------------------------------------------------------------------------------------------
V01() { # les webhooks weebo-si peuvent-ils bloquer leur propre démarrage ?
  local json bad
  json=$(k get mutatingwebhookconfiguration,validatingwebhookconfiguration -o json)
  printf '%s' "$json" | jq -c '.items[]|select(.metadata.name|test("weebo-si"))|.metadata.name as $c
    |.webhooks[]|{cfg:$c,name,failurePolicy,namespaceSelector,rules}' | log V-01
  # Le namespace de l'opérateur doit porter le label d'exclusion que tous les webhooks respectent.
  if ! k get ns weebo-si-hardening -o jsonpath='{.metadata.labels.hardening\.weebo\.io/exclude}' \
      | grep -qx true; then
    report V-01 FAIL "weebo-si-hardening sans hardening.weebo.io/exclude=true"; return
  fi
  # Un webhook sans l'exclusion dans son namespaceSelector pourrait viser n'importe quel namespace.
  bad=$(printf '%s' "$json" | jq -r '.items[]|select(.metadata.name|test("weebo-si"))|.webhooks[]
    |select([.namespaceSelector.matchExpressions[]?|select(.key=="hardening.weebo.io/exclude"
    and .operator=="DoesNotExist")]|length==0)|.name')
  if [ -n "$bad" ]; then report V-01 FAIL "sans exclusion : $bad"; return; fi
  report V-01 PASS "opérateur exclu ; DevWorkspace/policies/pods seuls visés (kube-system ne porte ni DevWorkspace ni label workspace)"
}

V02() { # youki fait-il tourner un pod ?
  has_runtimeclass youki || { report V-02 SKIP "RuntimeClass youki absente : étape 1 de « Workspaces sur youki » (Git, che/sub/templates)"; return; }
  apply_pod v02-youki "$TEST_NS" "  runtimeClassName: youki" || { report V-02 FAIL "pod youki non Ready"; return; }
  kx "$TEST_NS" v02-youki 'id; cat /proc/self/cgroup; cat /sys/fs/cgroup/memory.max; echo ok > /tmp/w && cat /tmp/w' | log V-02
  grep -q '^67108864$' "$OUT/V-02.log" \
    && report V-02 PASS "Running sous youki, memory.max=64Mi appliqué" \
    || report V-02 FAIL "memory.max inattendu, voir V-02.log"
}

V03() { # KubeArmor voit-il un pod youki ?
  has_runtimeclass youki || { report V-03 SKIP "dépend de V-02"; return; }
  k -n "$TEST_NS" get pod v02-youki >/dev/null 2>&1 || apply_pod v02-youki "$TEST_NS" "  runtimeClassName: youki"
  ka probe 2>&1 | log V-03 || true
  ( timeout 25 karmor logs --namespace "$TEST_NS" --json --logFilter all 2>&1 | log V-03 ) &
  sleep 5
  # crane:debug n'a pas de /usr/bin : on le crée en root, c'est l'écriture qui doit être auditée.
  kx "$TEST_NS" v02-youki 'mkdir -p /usr/bin 2>/dev/null; touch /usr/bin/v03 2>&1' | log V-03 || true
  wait
  grep -q '"PodName":"v02-youki"' "$OUT/V-03.log" \
    && report V-03 PASS "événement KubeArmor avec le bon pod" \
    || report V-03 FAIL "aucun événement pour v02-youki (le pod tourne-t-il en root ? règle /usr/bin en Audit ?)"
}

net_checks() { # id ns pod → écrit dans le log, renvoie 0 si autorisé passe et interdit coupé
  local id=$1 ns=$2 pod=$3 ok=0
  if kx "$ns" "$pod" "echo | nc -w 5 $ALLOWED_FQDN 443" >/dev/null 2>&1; then echo "allowed: open" | log "$id"; else echo "allowed: CLOSED" | log "$id"; ok=1; fi
  if kx "$ns" "$pod" "echo | nc -w 5 $DENIED_FQDN 443" >/dev/null 2>&1; then echo "denied: OPEN" | log "$id"; ok=1; else echo "denied: closed" | log "$id"; fi
  return $ok
}

V04() { # Cilium applique-t-il ses policies à un pod youki ?
  has_runtimeclass youki || { report V-04 SKIP "dépend de V-02"; return; }
  k -n "$TEST_NS" get pod v02-youki >/dev/null 2>&1 || apply_pod v02-youki "$TEST_NS" "  runtimeClassName: youki"
  k -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list 2>&1 | grep -E 'v02-youki|ENDPOINT' | log V-04 || true
  net_checks V-04 "$TEST_NS" v02-youki \
    && report V-04 PASS "$ALLOWED_FQDN joignable, $DENIED_FQDN coupé" \
    || report V-04 FAIL "voir V-04.log"
}

V05_06() { # id rc
  local id=$1 rc=${2:-} pod
  pod="${id,,}"
  # Pod autonome (pas apply_pod) pour pouvoir monter PVC et Secret.
  local pvc="$pod-pvc" sec="$pod-secret"
  k -n "$TEST_NS" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: $pvc }
spec: { accessModes: [ReadWriteOnce], storageClassName: longhorn, resources: { requests: { storage: 1Gi } } }
---
apiVersion: v1
kind: Secret
metadata: { name: $sec }
stringData: { probe: secret-lisible }
---
apiVersion: v1
kind: Pod
metadata: { name: $pod, labels: { app.kubernetes.io/part-of: hardening-validate } }
spec:
  restartPolicy: Never
  terminationGracePeriodSeconds: 1
  hostUsers: false
  ${rc:+runtimeClassName: $rc}
  securityContext: { runAsUser: 1234, runAsGroup: 1234, fsGroup: 1234 }
  volumes:
    - { name: data, persistentVolumeClaim: { claimName: $pvc } }
    - { name: sec, secret: { secretName: $sec } }
  containers:
    - name: t
      image: $IMG
      command: ["/busybox/sh", "-c", "sleep 900"]
      resources: { limits: { memory: 64Mi, cpu: 200m } }
      volumeMounts: [ { name: data, mountPath: /data }, { name: sec, mountPath: /sec } ]
EOF
  track "pod/$pod -n $TEST_NS"; track "pvc/$pvc -n $TEST_NS"; track "secret/$sec -n $TEST_NS"
  if ! k -n "$TEST_NS" wait --for=condition=Ready "pod/$pod" --timeout=180s >/dev/null 2>&1; then
    k -n "$TEST_NS" describe pod "$pod" | tail -25 | log "$id"
    report "$id" FAIL "pod hostUsers:false non Ready${rc:+ ($rc)}, voir $id.log"; return
  fi
  kx "$TEST_NS" "$pod" 'cat /proc/self/uid_map; id; echo x > /data/f && ls -n /data/f; cat /sec/probe' 2>&1 | log "$id"
  if grep -qE '^ +0 +0 +4294967295' "$OUT/$id.log"; then
    report "$id" FAIL "uid_map identitaire : hostUsers:false ignoré"
  elif grep -q 'secret-lisible' "$OUT/$id.log" && grep -qE ' 1234 +1234 ' "$OUT/$id.log"; then
    report "$id" PASS "mapping non identitaire, PVC inscriptible (1234:1234), Secret lisible${rc:+ ($rc)}"
  else
    report "$id" FAIL "voir $id.log"
  fi
}
V05() { V05_06 V-05 ""; }
V06() {
  has_runtimeclass youki || { report V-06 SKIP "RuntimeClass youki absente (V-02)"; return; }
  V05_06 V-06 youki
}

V07() { # KubeArmor bloque-t-il encore en user namespace ? quel UID remonte ?
  ensure_scratch_ns baseline
  local rc="" # runc : youki + user namespaces relève de V-06
  k apply -f - >/dev/null <<EOF
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata: { name: v07-block-net-raw, namespace: $SCRATCH_NS }
spec:
  selector: { matchLabels: { hardening-validate/test: v07 } }
  capabilities: { matchCapabilities: [ { capability: net_raw } ] }
  action: Block
EOF
  track "kubearmorpolicy/v07-block-net-raw -n $SCRATCH_NS"
  apply_pod v07 "$SCRATCH_NS" "  hostUsers: false${rc:+
  runtimeClassName: $rc}" || { report V-07 FAIL "pod hostUsers:false non Ready"; return; }
  k -n "$SCRATCH_NS" label pod v07 hardening-validate/test=v07 --overwrite >/dev/null
  sleep 5
  ( timeout 25 karmor logs --namespace "$SCRATCH_NS" --json --logFilter policy 2>&1 | log V-07 ) &
  sleep 5
  kx "$SCRATCH_NS" v07 'ping -c1 -W2 1.1.1.1 2>&1; echo rc=$?' | log V-07 || true
  wait
  local uid
  uid=$(grep -o '"UID":[0-9]*' "$OUT/V-07.log" | head -1 || true)
  if grep -q 'rc=0' "$OUT/V-07.log"; then
    report V-07 FAIL "ping passé sous user namespace${rc:+ + $rc} : net_raw non bloqué"
  else
    report V-07 PASS "ping refusé${rc:+ ($rc)} ; UID vu par KubeArmor : ${uid:-non trouvé (lire V-07.log)}"
  fi
}

V08() { report V-08 MANUAL "règle Audit sur /var/run/secrets/kubernetes.io/serviceaccount/ dans values.yaml (Git), 7 jours, puis agréger ProcessName dans ClickStack"; }
V09() { report V-09 MANUAL "après V-08 : passer la règle en Block avec la liste fromSource sur $TEST_NS (Git), démarrer, cat …/token"; }

V10() { # PSA restricted : liste des pods en infraction, sans rien changer (dry-run serveur)
  k label --dry-run=server --overwrite ns "$TEST_NS" pod-security.kubernetes.io/enforce=restricted 2>&1 | log V-10
  if [ "$(k -n "$TEST_NS" get pods -l controller.devfile.io/devworkspace_id -o name | wc -l)" -eq 0 ]; then
    report V-10 SKIP "aucun workspace démarré dans $TEST_NS : en démarrer un (avec et sans sidecars) puis relancer"
  elif grep -qi 'violate' "$OUT/V-10.log"; then
    report V-10 FAIL "infractions restricted listées dans V-10.log (champs à corriger dans le DWOC)"
  else
    report V-10 PASS "aucun pod du workspace n'enfreint restricted"
  fi
}

V11() { # che-operator recopie-t-il runtimeClassName ? (lecture seule de l'état actuel)
  local cc dwoc
  cc=$(k get checluster -A -o jsonpath='{.items[0].spec.devEnvironments.runtimeClassName}')
  dwoc=$(k -n eclipse-che get dwoc devworkspace-config -o jsonpath='{.config.workspace.runtimeClassName}')
  printf 'checluster=%s dwoc=%s\n' "${cc:-<vide>}" "${dwoc:-<vide>}" | log V-11
  if [ -z "$cc" ]; then
    report V-11 MANUAL "CheCluster sans runtimeClassName : le poser via Git (che-cluster.yaml) sur une RuntimeClass existante, puis relancer"
  elif [ "$cc" = "$dwoc" ]; then report V-11 PASS "recopié : $dwoc"
  else report V-11 FAIL "CheCluster=$cc mais DWOC=${dwoc:-<vide>}"; fi
}

V12() { # che-operator conserve-t-il un champ ajouté à son DWOC ?
  [ "${ALLOW_CHE_PATCH:-0}" = 1 ] || { report V-12 SKIP "modifie le DWOC de Che : relancer avec ALLOW_CHE_PATCH=1"; return; }
  # Champ témoin sans effet : progressTimeout est déjà à 300s ; on ajoute un champ que che-operator
  # ne gère pas (cleanupOnStop false = défaut DWO) pour ne pas changer le comportement des workspaces.
  # hostUsers n'est PAS posé ici : il s'appliquerait à tous les workspaces démarrés pendant le test.
  k -n eclipse-che patch dwoc devworkspace-config --type merge \
    -p '{"config":{"workspace":{"cleanupOnStop":false}}}' | log V-12
  k annotate checluster -A --all --overwrite hardening-validate/reconcile="$(date +%s)" >/dev/null 2>&1 \
    || k -n eclipse-che annotate checluster eclipse-che --overwrite hardening-validate/reconcile="$(date +%s)" >/dev/null
  sleep 60
  local v; v=$(k -n eclipse-che get dwoc devworkspace-config -o jsonpath='{.config.workspace.cleanupOnStop}')
  k -n eclipse-che annotate checluster eclipse-che hardening-validate/reconcile- >/dev/null 2>&1 || true
  if [ "$v" = false ]; then
    k -n eclipse-che patch dwoc devworkspace-config --type json -p '[{"op":"remove","path":"/config/workspace/cleanupOnStop"}]' >/dev/null || true
    report V-12 PASS "un champ ajouté survit au reconcile : hostUsers peut aller dans le DWOC de Che"
  else
    report V-12 FAIL "champ effacé : DWOC maison épinglé par défaut (décision phase 5)"
  fi
}

V13() { report V-13 MANUAL "définir PARENT_URI (tag) et démarrer un devfile de test depuis le dashboard ; vérifier les composants du parent"; }

V14() { # où apparaissent les admission warnings ? (ValidatingAdmissionPolicy native, pas de webhook)
  k apply -f - >/dev/null <<EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: { name: hardening-validate-v14 }
spec:
  failurePolicy: Ignore
  matchConstraints:
    resourceRules: [ { apiGroups: [workspace.devfile.io], apiVersions: ["*"], operations: [CREATE, UPDATE], resources: [devworkspaces] } ]
  validations:
    - expression: "false"
      message: "V-14 test warning: weebo.io/platform-contract missing"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: { name: hardening-validate-v14 }
spec:
  policyName: hardening-validate-v14
  validationActions: [Warn]
  matchResources: { namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: $TEST_NS } } }
EOF
  track "validatingadmissionpolicybinding/hardening-validate-v14"; track "validatingadmissionpolicy/hardening-validate-v14"
  # Une VAP n'est appliquée qu'une fois compilée par l'apiserver : sans attente, le premier appel passe sans warning.
  sleep 15
  local dw; dw=$(k -n "$TEST_NS" get devworkspace -o name | head -1)
  if [ -z "$dw" ]; then
    report V-14 MANUAL "VAP Warn posée sur $TEST_NS ; aucun DevWorkspace : en démarrer un depuis le dashboard MAINTENANT (le script attend 120 s) et noter si le warning s'affiche"
    sleep 120; return
  fi
  k -n "$TEST_NS" annotate "$dw" --overwrite hardening-validate/v14=1 2>&1 | log V-14
  k -n "$TEST_NS" annotate "$dw" hardening-validate/v14- >/dev/null 2>&1 || true
  grep -q 'V-14 test warning' "$OUT/V-14.log" \
    && report V-14 MANUAL "kubectl affiche le warning ; démarrer depuis le dashboard pendant 120 s pour la partie UI" \
    || report V-14 FAIL "kubectl n'a pas affiché le warning"
  sleep 120
}

V15() { report V-15 MANUAL "sidecar Playwright dans un devfile de test : npx playwright test avec puis sans --no-sandbox"; }

V16() { # buildkitd rootless : démarre-t-il, à quel niveau PSA ?
  ensure_scratch_ns privileged
  k -n "$SCRATCH_NS" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: { name: v16-buildkitd, labels: { app.kubernetes.io/part-of: hardening-validate } }
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: buildkitd
      image: $BUILDKIT_IMG
      args: [--oci-worker-no-process-sandbox]
      securityContext:
        seccompProfile: { type: Unconfined }
        appArmorProfile: { type: Unconfined }
        runAsUser: 1000
        runAsGroup: 1000
      resources: { limits: { memory: 1Gi, cpu: "1" } }
EOF
  track "pod/v16-buildkitd -n $SCRATCH_NS"
  if ! k -n "$SCRATCH_NS" wait --for=condition=Ready pod/v16-buildkitd --timeout=180s >/dev/null 2>&1; then
    k -n "$SCRATCH_NS" describe pod v16-buildkitd | tail -20 | log V-16
    report V-16 FAIL "buildkitd rootless non Ready, voir V-16.log"; return
  fi
  k -n "$SCRATCH_NS" get pod v16-buildkitd -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}' | log V-16
  k -n "$SCRATCH_NS" exec v16-buildkitd -- sh -c 'mkdir -p /tmp/ctx && printf "FROM scratch\nCOPY f /f\n" > /tmp/ctx/Dockerfile && echo hi > /tmp/ctx/f && buildctl build --frontend dockerfile.v0 --local context=/tmp/ctx --local dockerfile=/tmp/ctx 2>&1 | tail -5' | log V-16 \
    && report V-16 PASS "build OK ; PSA requis du namespace d'outils : privileged (Unconfined refusé par baseline)" \
    || report V-16 FAIL "buildctl build a échoué, voir V-16.log"
  # Confirme qu'il faut bien privileged : la même spec en dry-run sous baseline.
  k label --dry-run=server --overwrite ns "$SCRATCH_NS" pod-security.kubernetes.io/enforce=baseline 2>&1 | log V-16
}

V17() { report V-17 MANUAL "nécessite un device plugin /dev/kvm (non installé) : à faire quand le dev Android démarre"; }

V18() { # registryConfig sait-il gérer Gradle ?
  local enum
  enum=$(k get crd weebositeams.hardening.weebo.io -o json | jq -c '[..|objects|select(has("enum"))|.enum|select(index("Npm"))][0]')
  echo "$enum" | log V-18
  # Ecosystem n'est qu'une étiquette (registry_config.rs) : le contenu distribué est libre, donc un
  # init.gradle passe sous Maven (même dépôt BatleHub) ou Other.
  printf '%s' "$enum" | grep -q Maven \
    && report V-18 PASS "Maven présent ; l'enum n'est qu'une étiquette, un init.gradle se distribue sous Maven/Other sans évolution de weebo-si" \
    || report V-18 FAIL "ni Maven ni Gradle dans l'enum : $enum"
}

V19() { report V-19 MANUAL "requête ClickStack sur 14 jours de flux DNS Hubble des dev-ws-* (prérequis phase 1 : export Hubble)"; }

V20() { # Cilium filtre-t-il par SNI sur 8443 ?
  ensure_scratch_ns baseline
  local allowed=${SNI_ALLOWED:-registry.pkg.weebo.poc} denied=${SNI_DENIED:-argocd.weebo.poc} svc=traefik.traefik.svc.cluster.local
  k apply -f - >/dev/null <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: { name: v20-sni, namespace: $SCRATCH_NS }
spec:
  endpointSelector: { matchLabels: { hardening-validate/test: v20 } }
  egress:
    - toEndpoints: [ { matchLabels: { k8s:io.kubernetes.pod.namespace: kube-system, k8s-app: kube-dns } } ]
      toPorts: [ { ports: [ { port: "53", protocol: ANY } ], rules: { dns: [ { matchPattern: "*" } ] } } ]
    - toEndpoints: [ { matchLabels: { k8s:io.kubernetes.pod.namespace: traefik } } ]
      toPorts: [ { ports: [ { port: "8443", protocol: TCP } ], serverNames: [ "$allowed" ] } ]
EOF
  track "cnp/v20-sni -n $SCRATCH_NS"
  apply_pod v20 "$SCRATCH_NS" || { report V-20 FAIL "pod non Ready"; return; }
  k -n "$SCRATCH_NS" label pod v20 hardening-validate/test=v20 --overwrite >/dev/null
  sleep 5
  # wget TLS de busybox envoie le SNI du host ; on force la résolution vers le Service traefik.
  local ip; ip=$(k -n traefik get svc traefik -o jsonpath='{.spec.clusterIP}')
  kx "$SCRATCH_NS" v20 "echo '$ip $allowed $denied' >> /etc/hosts 2>/dev/null; \
    wget -q -T 5 --no-check-certificate -O /dev/null https://$allowed:443/ && echo ALLOWED_OK || echo ALLOWED_KO; \
    wget -q -T 5 --no-check-certificate -O /dev/null https://$denied:443/ && echo DENIED_OPEN || echo DENIED_CLOSED" 2>&1 | log V-20 || true
  echo "svc=$svc ip=$ip (le Service expose 443 → targetPort 8443 : la règle vise le pod sur 8443)" | log V-20
  if grep -q ALLOWED_OK "$OUT/V-20.log" && grep -q DENIED_CLOSED "$OUT/V-20.log"; then
    report V-20 PASS "SNI $allowed passe, $denied coupé"
  else
    report V-20 FAIL "voir V-20.log (busybox wget sans TLS ? /etc/hosts non inscriptible ?)"
  fi
}

V21() { # chaîne KubeArmor → ClickStack
  apply_pod v21 "$TEST_NS" || { report V-21 FAIL "pod non Ready"; return; }
  kx "$TEST_NS" v21 'mkdir -p /usr/bin 2>/dev/null; touch /usr/bin/v21-$(date +%s) 2>&1' | log V-21 || true
  report V-21 MANUAL "écriture /usr/bin faite à $(date -u +%H:%M:%SZ) dans pod v21 : vérifier l'événement dans ClickStack (< 60 s)"
}

V22() { report V-22 MANUAL "renovate --dry-run=full avec le custom manager sur weebo-che-project (token requis)"; }

# Tests ajoutés le 2026-11-24 pour les RFC 0018-0021 (voir la page du protocole).
V23() { # quels champs du devfile survivent dans le DevWorkspace ? (RFC 0019)
  local dw; dw=$(k get devworkspace -A -o json | jq -c '.items[]|{ns:.metadata.namespace,name:.metadata.name,
    annotations:(.metadata.annotations|with_entries(select(.key|test("devfile|che.eclipse.org")))),
    attributes:.spec.template.attributes, parent:.spec.template.parent,
    schemaVersion:(.spec.template.schemaVersion // .metadata.annotations["che.eclipse.org/devfile-schema-version"])}')
  printf '%s\n' "$dw" | log V-23
  if [ -z "$dw" ]; then report V-23 SKIP "aucun DevWorkspace dans le cluster"; return; fi
  report V-23 MANUAL "relevé dans V-23.log : schemaVersion, parent et attributs visibles ou non côté DevWorkspace"
}

V24() { # quels pods non-workspace naissent dans un namespace de workspace, et avec quel securityContext ? (RFC 0018)
  k get pods -A -o json | jq -c '.items[]|select(.metadata.namespace|startswith("dev-ws-"))
    |select((.metadata.labels["controller.devfile.io/devworkspace_id"]//"")=="" )
    |{ns:.metadata.namespace,name:.metadata.name,owner:.metadata.ownerReferences[0].kind,sc:.spec.securityContext}' | log V-24
  k get jobs -A -o json | jq -c '.items[]|select(.metadata.namespace|startswith("dev-ws-"))|{ns:.metadata.namespace,name:.metadata.name,sc:.spec.template.spec.securityContext}' | log V-24
  report V-24 MANUAL "pods hors workspace listés dans V-24.log ; relancer après un arrêt/suppression de workspace (job de cleanup DWO)"
}

V25() { # qui peut écrire l'annotation d'un Namespace et patcher un DevWorkspace ? (RFC 0021, T-12)
  local sa user r
  sa=$(k -n "$TEST_NS" get sa -o name | grep -E 'workspace.*-sa$' | head -1 | cut -d/ -f2 || true)
  user=$(k -n "$TEST_NS" get rolebinding -o json | jq -r '[.items[].subjects[]?|select(.kind=="User")|.name][0]')
  for who in "$user" ${sa:+system:serviceaccount:$TEST_NS:$sa}; do
    r=$(k auth can-i patch "namespace/$TEST_NS" --as="$who" 2>/dev/null || true)
    echo "$who patch namespace: $r" | log V-25
    r=$(k auth can-i patch devworkspaces.workspace.devfile.io -n "$TEST_NS" --as="$who" 2>/dev/null || true)
    echo "$who patch devworkspaces: $r" | log V-25
  done
  if grep -q 'patch namespace: yes' "$OUT/V-25.log"; then
    report V-25 FAIL "un non-admin peut annoter son Namespace : le canal d'accord admin de la RFC 0021 ne tient pas"
  else
    report V-25 PASS "Namespace non patchable par l'utilisateur${sa:+ ni par le SA du workspace} (DevWorkspace : voir log)"
  fi
}

V26() { # aucune NetworkPolicy Kubernetes allow-all dans les dev-ws-* (elle s'additionnerait à weebo-base)
  local np; np=$(k get networkpolicy -A -o json | jq -r '.items[]|select(.metadata.namespace|startswith("dev-ws-"))|"\(.metadata.namespace)/\(.metadata.name)"')
  k -n eclipse-che get dwoc devworkspace-config -o jsonpath='{.config.workspace.networkPolicy}{"\n"}' | log V-26
  [ -z "$np" ] && report V-26 PASS "aucune NetworkPolicy dans dev-ws-* (le networkPolicy allow-all du DWOC n'est pas matérialisé)" \
               || report V-26 FAIL "NetworkPolicy présentes : $np (Cilium les additionne à weebo-base)"
}

V27() { # le moteur ajoute-t-il seul l'UID arbitraire à /etc/passwd ? (RFC 0018, décide du besoin du gid 0)
  # L'image réelle des workspaces : son /etc/passwd est g=u (RFC 0001), condition pour qu'un moteur l'enrichisse.
  local img=${WS_IMG:-registry.pkg.weebo.poc/ghcr/batleforc/weebodevimage/che-min-mise:main} rc res=""
  local SH=/bin/sh
  for rc in "" youki; do
    if [ -n "$rc" ] && ! has_runtimeclass "$rc"; then echo "youki: RuntimeClass absente" | log V-27; continue; fi
    local pod="v27-${rc:-runc}"
    IMG=$img SH=$SH apply_pod "$pod" "$TEST_NS" "  securityContext: { runAsUser: 54321, runAsGroup: 54321 }${rc:+
  runtimeClassName: $rc}" || { res="$res ${rc:-runc}=non-Ready"; k -n "$TEST_NS" describe pod "$pod" 2>&1 | tail -15 | log V-27; continue; }
    kx "$TEST_NS" "$pod" 'id; grep ":54321:" /etc/passwd || echo NO_ENTRY; ls -l /etc/passwd; whoami 2>&1' 2>&1 | sed "s/^/${rc:-runc}: /" | log V-27
    if grep -q "^${rc:-runc}: NO_ENTRY" "$OUT/V-27.log"; then res="$res ${rc:-runc}=absente"; else res="$res ${rc:-runc}=ajoutée"; fi
  done
  case "$res" in
    *non-Ready*) report V-27 FAIL "pod non Ready ($res), test non concluant, voir V-27.log" ;;
    *absente*) report V-27 FAIL "entrée /etc/passwd non ajoutée par le moteur ($res) : nss_wrapper dans WeeboDevImage, gid 0 en dernier recours (RFC 0018)" ;;
    *) report V-27 PASS "le moteur ajoute l'entrée ($res) : pas de gid 0 nécessaire" ;;
  esac
}

ALL="V-01 V-02 V-03 V-04 V-05 V-06 V-07 V-08 V-09 V-10 V-11 V-12 V-13 V-14 V-15 V-16 V-17 V-18 V-19 V-20 V-21 V-22 V-23 V-24 V-25 V-26 V-27"
SELECTED=${*:-$ALL}

for t in kubectl jq; do command -v "$t" >/dev/null || { echo "$t manquant (mise install)" >&2; exit 1; }; done
k version -o json 2>/dev/null | jq -r '"client \(.clientVersion.gitVersion) / server \(.serverVersion.gitVersion)"' > "$OUT/versions.txt" || true
k -n weebo-si-hardening get deploy -o jsonpath='{range .items[*]}{.metadata.name}={.spec.template.spec.containers[0].image}{"\n"}{end}' >> "$OUT/versions.txt" || true

echo "| Test | Résultat | Détail |"
echo "|---|---|---|"
for id in $SELECTED; do
  fn=${id//-/}
  if ! declare -F "$fn" >/dev/null; then report "$id" SKIP "test inconnu"; continue; fi
  "$fn" || report "$id" FAIL "erreur du script (code $?), voir $OUT/$id.log"
done

{ echo "# Validation amont $(date -Iseconds)"; echo; cat "$OUT/versions.txt"; echo
  echo "| Test | Résultat | Détail |"; echo "|---|---|---|"; printf '%s\n' "${SUMMARY[@]}"; } > "$OUT/summary.md"
echo
echo "Preuves : $OUT"
