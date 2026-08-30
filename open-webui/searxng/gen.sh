#!/bin/bash

set -euo pipefail

# regenerate settings file with secrets from .env

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../.env"


: "${BRAVE_SEARCH_API_KEY:?Missing BRAVE_SEARCH_API_KEY in .env}"

template=$(< "$SCRIPT_DIR/settings.yml.in")
rendered=${template//__BRAVE_SEARCH_API_KEY__/"$BRAVE_SEARCH_API_KEY"}

umask 077
rm -f "$SCRIPT_DIR/settings.yml" || :
printf '%s\n' "$rendered" > "$SCRIPT_DIR/settings.yml"
