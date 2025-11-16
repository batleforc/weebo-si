export CLUSTER_NAME="kamalos"
export NAMESPACE="kamalos"
export WORKER_IP="10.244.0.43"
export WORKER_IP_2="10.244.0.188"
export KUBERNETES_VERSION="v1.33.2"
export TALOS_VERSION="v1.11.5"
export CONTROL_PLANE_IP="10.96.70.1"

task aio:kubectl -- get secret ${CLUSTER_NAME}-admin-kubeconfig -n $NAMESPACE \
  -o jsonpath='{.data.admin\.conf}' | base64 -d > ./tmp/${NAMESPACE}-${CLUSTER_NAME}.kubeconfig

K8S_CA=$(cat ./tmp/kamalos-kamalos.kubeconfig | yq .clusters[0].cluster.certificate-authority-data)

K8S_BOOTSTRAP_TOKEN=$(kubeadm --kubeconfig=./tmp/${NAMESPACE}-${CLUSTER_NAME}.kubeconfig token create)

# Re-extract credentials from secrets.yaml (keep base64 encoded for worker.yaml)
TALOS_CA_CRT=$(yq -r '.certs.os.crt' ./tmp/secrets.yaml)
TALOS_TOKEN=$(yq -r '.trustdinfo.token' ./tmp/secrets.yaml)
TALOS_CLUSTER_ID=$(yq -r '.cluster.id' ./tmp/secrets.yaml)
TALOS_CLUSTER_SECRET=$(yq -r '.cluster.secret' ./tmp/secrets.yaml)

cat > ./tmp/worker.yaml <<EOF
version: v1alpha1
persist: true
machine:
  type: worker
  token: ${TALOS_TOKEN}
  ca:
    crt: ${TALOS_CA_CRT}
    key: ""
  kubelet:
    image: ghcr.io/siderolabs/kubelet:${KUBERNETES_VERSION}
    extraArgs:
      rotate-certificates: "true"
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:${TALOS_VERSION}
  features:
    rbac: true
    kubePrism:
      enabled: false
cluster:
  id: ${TALOS_CLUSTER_ID}
  secret: ${TALOS_CLUSTER_SECRET}
  controlPlane:
    endpoint: https://${CONTROL_PLANE_IP}:6443
  clusterName: ${CLUSTER_NAME}
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.246.0.0/16
    serviceSubnets:
      - 10.128.0.0/12
  token: ${K8S_BOOTSTRAP_TOKEN}
  ca:
    crt: ${K8S_CA}
    key: ""
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: true
      service:
        disabled: true
EOF

echo "Generated worker configuration at ./tmp/worker.yaml"

echo "Worker join command:"

talosctl apply-config --insecure --nodes $WORKER_IP --file ./tmp/worker.yaml
talosctl apply-config --insecure --nodes $WORKER_IP_2 --file ./tmp/worker.yaml