
This is a small systemd service that listens on a fifo
and maps llmux commands to docker start commands.

install it with ./install.sh

It will create a systemd service called llmux-fifo, which will
be listening for commands on /var/run/llmux-fifo/llmux.fifo

