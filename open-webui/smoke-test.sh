#!/bin/bash

set -e

curl -I http://127.0.0.1:3000

docker compose exec open-webui \
  curl -fsS \
  'http://searxng:8080/search?q=llama.cpp&format=json' |
jq -r '
  "results: \(.results | length)",
  (.results[:5][] | "\(.title)\n  \(.url)")
'