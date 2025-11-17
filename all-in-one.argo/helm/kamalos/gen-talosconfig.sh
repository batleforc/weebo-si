export worker_ip=$(task aio:kubectl -- -n kamalos get pod -o yaml | yq '.items[] | select(.metadata.name | match("virt-launcher-kamalos-worker.*")) | .status.podIP')

talosctl gen config kamalos https://10.96.70.1:6443 \
  --with-secrets ./tmp/secrets.yaml \
  --output-types talosconfig \
  --output ./tmp/talosconfig \
  --force

talosctl --talosconfig=./tmp/talosconfig config endpoint $worker_ip