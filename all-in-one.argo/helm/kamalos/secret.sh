TALOS_CA_CRT=$(yq -r '.certs.os.crt' ./all-in-one.argo/helm/kamalos/tmp/secrets.yaml | base64 -d)
# Talos uses "BEGIN ED25519 PRIVATE KEY" but cert-manager requires "BEGIN PRIVATE KEY" (RFC 7468)
TALOS_CA_KEY=$(yq -r '.certs.os.key' ./all-in-one.argo/helm/kamalos/tmp/secrets.yaml | base64 -d | sed 's/ED25519 //g')
TALOS_TOKEN=$(yq -r '.trustdinfo.token' ./all-in-one.argo/helm/kamalos/tmp/secrets.yaml)
TALOS_CLUSTER_ID=$(yq -r '.cluster.id' ./all-in-one.argo/helm/kamalos/tmp/secrets.yaml)
TALOS_CLUSTER_SECRET=$(yq -r '.cluster.secret' ./all-in-one.argo/helm/kamalos/tmp/secrets.yaml)

task aio:kubectl -- create secret generic kamalos-talos-ca -n kamalos \
  --from-literal=tls.crt="$TALOS_CA_CRT" \
  --from-literal=tls.key="$TALOS_CA_KEY" \
  --from-literal=token="$TALOS_TOKEN"