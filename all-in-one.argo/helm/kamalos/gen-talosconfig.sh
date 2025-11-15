
talosctl gen config kamalos https://10.96.70.1:6443 \
  --with-secrets ./tmp/secrets.yaml \
  --output-types talosconfig \
  --output ./tmp/talosconfig \
  --force

talosctl --talosconfig=./tmp/talosconfig config endpoint 10.244.0.57