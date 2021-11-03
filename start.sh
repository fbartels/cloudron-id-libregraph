#!/bin/bash
set -euo pipefail

set -x

mkdir -p /app/data/tls

if [ ! -e /app/data/tls/root-ca.crt ]; then
    cd /app/data/tls
    step certificate create root-ca root-ca.crt root-ca.key --profile root-ca --no-password --insecure
    # this step fails on cloudron because of read-only
    #step certificate install root-ca.crt
    step certificate create "$CLOUDRON_APP_DOMAIN" server.crt server.key --profile leaf --ca ./root-ca.crt --ca-key ./root-ca.key --not-after "$(date --date "next year" -Iseconds)" --no-password --insecure
    step certificate bundle server.crt root-ca.crt fullchain.pem
    ln -sfn server.key fullchain.pem.key
    chmod 644 fullchain.pem root-ca.crt
    chmod 640 server.key
    chgrp www-data server.key
fi

mkdir -p /app/data/www/.well-known
ln -sf /app/data/tls/root-ca.crt /app/data/www/.well-known/

if [ ! -e /app/data/README.md ]; then
    cat <<EOF > /app/data/README.md
Adding users: https://github.com/libregraph/idm#add-new-users-using-the-gen-newusers-command
Adding additional service users: https://github.com/libregraph/idm#adding-a-service-user-for-ldap-access
Migrate from OpenLDAP: https://github.com/libregraph/idm#replace-existing-openldap-with-idm
fi

echo "=> Ensure permissions"
chown -R cloudron:cloudron /run /app/data

exec /usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf --nodaemon -i cloudron-id