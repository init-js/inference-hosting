#!/usr/bin/bash

set -exuo pipefail

HEREDIR=$(cd "$(dirname "$0")" && pwd)

# directory where VLLM compose files are located
VLLM_DIR=$(readlink -f "$HEREDIR/../../vllm")

# create a system user (one-time)
sudo useradd -r -s /usr/sbin/nologin llmux || true

for script in "$HEREDIR"/llmux-*; do
    sudo install -m 750 -o root -g root "$script" /usr/local/sbin/$(basename "$script")
done

chown llmux /usr/local/sbin/llmux-fifo-listener

# create a minimal sudoers file allowing only the wrapper
cat > /tmp/llmux-sudo.tmp <<'SUDO'
llmux ALL=(root) NOPASSWD: /usr/local/sbin/llmux-docker
SUDO

:
: INSPECT / VALIDATE RESULT
:
sudo visudo -cf /tmp/llmux-sudo.tmp
sudo mv /tmp/llmux-sudo.tmp /etc/sudoers.d/llmux
sudo chmod 0440 /etc/sudoers.d/llmux

# copy unit file (edit path as needed)
sudo tee /etc/systemd/system/llmux-fifo.service > /dev/null <<EOF
[Unit]
Description=LLMux FIFO listener
After=network.target

[Service]
Type=simple
User=llmux
Environment=FIFO_PATH=/run/llmux-fifo/llmux.fifo
Environment=COMPOSE_DIR=${VLLM_DIR}
ExecStart=/usr/local/sbin/llmux-fifo-listener
Restart=on-failure
RestartSec=5

# keep the fifo around when we shut it down, because
# the writers (in the docker container) might otherwise
# be forever waiting on a fifo that never have a receiving end
RuntimeDirectoryPreserve=yes
RuntimeDirectory=llmux-fifo
RuntimeDirectoryMode=0750


[Install]
WantedBy=multi-user.target
EOF

# reload units, enable at boot, and start now
sudo systemctl daemon-reload
sudo systemctl enable --now llmux-fifo.service
sudo systemctl restart llmux-fifo.service
sleep 1
sudo systemctl status llmux-fifo.service

echo "Installation complete. To follow logs, run: sudo journalctl -u llmux-fifo -f"
