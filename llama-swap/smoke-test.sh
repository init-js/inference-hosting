#!/bin/bash

set -x

PORT=${PORT:-8080}

curl -N http://127.0.0.1:$PORT/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "reasoner",
    "messages": [
      {"role": "user", "content": "What is 17 * 23?"}
    ],
    "stream": true
  }'
