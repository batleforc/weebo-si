export CLUSTER_NAME="kamalos"
export NAMESPACE="kamalos"
export WORKER_IP="10.244.0.23"
export KUBERNETES_VERSION="v1.33.2"
export TALOS_VERSION="v1.11.5"
export CONTROL_PLANE_IP="10.96.70.1"

kubectl --kubeconfig=./tmp/${NAMESPACE}-${CLUSTER_NAME}.kubeconfig apply -f \
  https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml