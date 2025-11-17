export CLUSTER_NAME="kamalos"
export NAMESPACE="kamalos"
export WORKER_IPS=$(task aio:kubectl -- -n kamalos get pod -o yaml | yq '.items[] | select(.metadata.name | match("virt-launcher-kamalos-worker.*")) | .status.podIP')
export KUBERNETES_VERSION="v1.33.2"
export TALOS_VERSION="v1.11.5"
export CONTROL_PLANE_IP="10.96.70.1"
export CILIUM_NAMESPACE="cilium-system"

helm repo add cilium https://helm.cilium.io/

helm upgrade --install cilium cilium/cilium --version 1.18.4 \
  --kubeconfig ./tmp/${NAMESPACE}-${CLUSTER_NAME}.kubeconfig \
  --create-namespace \
  --namespace $CILIUM_NAMESPACE \
  -f ./cilium-values.yaml \
  --set=k8sServiceHost=${CONTROL_PLANE_IP}