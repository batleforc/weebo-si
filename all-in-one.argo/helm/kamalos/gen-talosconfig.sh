export worker_ip=$(./get_node_ip.sh)

talosctl gen config kamalos https://10.96.70.1:6443 \
  --with-secrets ./tmp/secrets.yaml \
  --output-types talosconfig \
  --output ./tmp/talosconfig \
  --force

talosctl --talosconfig=./tmp/talosconfig config endpoint $worker_ip