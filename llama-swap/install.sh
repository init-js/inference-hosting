#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

set -exuo pipefail
t=$(mktemp -d)

trap 'rm -rf -- "$t" || :' EXIT

cd $t
git clone https://github.com/mostlygeek/llama-swap.git
cd llama-swap
docker run --rm \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  -v "$PWD:/src" \
  -w /src \
  golang:1.26.1-bookworm \
  bash -c '
    apt-get update &&
    apt-get install -y curl make git ca-certificates &&
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - &&
    apt-get install -y nodejs &&
    node --version &&
    go version &&
    git config --global --add safe.directory /src &&
    make linux-amd64
  '

LLAMASWAPD=/usr/local/bin/llama-swap
LLAMASWAPCTL=/usr/local/sbin/llama-swap-ctl
LLAMASWAP_ETC=/etc/llama-swap
LLAMASWAP_HOME=/var/lib/llama-swap
LLAMASWAP_CONFIG="$LLAMASWAP_ETC/config.yaml"

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(realpath "$HERE/../llamacpp/compose.yaml")"
MODELS_INI="$(realpath "$HERE/../llamacpp/presets/models.ini")"

mkdir -p -- "$LLAMASWAP_ETC"
chown root:llamaswap -- "$LLAMASWAP_ETC"
chmod 755 -- "$LLAMASWAP_ETC"


install -m 755 \
    build/llama-swap-* \
    "$LLAMASWAPD"


if ! id llamaswap &>/dev/null; then
    useradd \
        --system \
        --home-dir "$LLAMASWAP_HOME" \
        --shell /usr/sbin/nologin \
        llamaswap
fi
install -d \
    -o llamaswap \
    -g llamaswap \
    -m 750 \
    "$LLAMASWAP_HOME"




# install scripts
for template in "$HERE/templates/"*.in; do
  outbin="/usr/local/sbin/$(basename "$template" .in)"
  sed -e "s|@@COMPOSE_FILE@@|$COMPOSE_FILE|g" \
      -e "s|@@MODELS_INI@@|$MODELS_INI|g" \
      -e "s|@@LLAMASWAPCTL@@|$LLAMASWAPCTL|g" \
      -e "s|@@LLAMASWAP_CONFIG@@|$LLAMASWAP_CONFIG|g" \
      "$template" > "$outbin"
  chown root:root "$outbin"
  chmod 755 "$outbin"
done

# refresh the config now
/usr/local/sbin/llama-config-refresh


# let llamaswap sudo that control script
SUDOERS_FILE=/etc/sudoers.d/llama-swap
tmp="$(mktemp)"
cat > "$tmp" <<EOF
llamaswap ALL=(root) NOPASSWD: ${LLAMASWAPCTL}
EOF
chmod 440 "$tmp"
chown root:root "$tmp"

if visudo -cf "$tmp"; then
    mv "$tmp" "$SUDOERS_FILE"
else
    echo "Invalid sudoers configuration" >&2
    rm -f "$tmp"
    exit 1
fi


#
# LLAMA SWAP DAEMON
#
cat > /etc/systemd/system/llama-swap.service <<EOF
[Unit]
Description=llama-swap model router
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=llamaswap
Group=llamaswap

ExecStart=$LLAMASWAPD \
    -config ${LLAMASWAP_CONFIG} \
    -listen 0.0.0.0:8080 \
    -watch-config

ExecStopPost=/usr/bin/sudo -n $LLAMASWAPCTL stop-all

Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

#
# LLAMA-SWAP-CONFIG REFRESHER
#
cat > /etc/systemd/system/llama-config-refresh.service <<EOF
[Unit]
Description=Regenerate llama-swap config

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/llama-config-refresh
EOF


#
# MODELS INI WATCHER
#
cat > /etc/systemd/system/llama-config-refresh.path <<EOF
[Unit]
Description=Watch llama.cpp models.ini

[Path]
PathChanged=${MODELS_INI}
Unit=llama-config-refresh.service

[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload
systemctl enable --now llama-swap
systemctl enable --now llama-config-refresh.path

