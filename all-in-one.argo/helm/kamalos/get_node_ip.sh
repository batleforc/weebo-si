
truc=$(task aio:kubectl -- -n kamalos get pod -o yaml | yq '.items[] | select(.metadata.name | match("virt-launcher-kamalos-worker.*")) | .status.podIP')

if [ -z "$ADDITIONAL_NODE" ]; then
  echo $truc
else
  echo "$truc $ADDITIONAL_NODE"
fi