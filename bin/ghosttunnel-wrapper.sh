#!/bin/bash
set -euo pipefail

# define defaults
some_option=${some_option:-"default value"}

exec /usr/local/bin/ghosttunnel server \
  --listen 0.0.0.0:7636 \
  --target 127.0.0.1:10389 \
  --cert /etc/certs/tls_cert.pem \
  --key /etc/certs/tls_key.pem \
  --quiet=conn-errs \
  --disable-authentication
