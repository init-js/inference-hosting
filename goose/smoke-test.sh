#!/bin/bash

cd "$(dirname "$0")"

docker compose exec goose \
  goose run --model coder -t \
  'Reply with exactly: Goose is connected to my AI'

sleep 3

docker compose exec \
  -e GOOSE_MODE=auto \
  goose \
  goose run --model coder -t \
  'Use the developer tools to print the current directory and list its immediate contents. Do not modify anything.'