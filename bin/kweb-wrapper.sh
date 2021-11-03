#!/bin/bash
set -euo pipefail

ULIMIT_FRONTEND=${ULIMIT_FRONTEND:-65536}

# modify open file limit unless 0 was specified as its value
if [ ! "$ULIMIT_FRONTEND" = 0 ]; then
    # set open file limit for public facing services
    ulimit -n "$ULIMIT_FRONTEND"
fi

export DEFAULTREDIRECT="/signin"

exec /usr/local/bin/kwebd caddy -conf /etc/Caddyfile
