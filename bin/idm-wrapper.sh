#!/bin/bash
set -euo pipefail

# define defaults
some_option=${some_option:-"default value"}

mkdir -p /app/data/ldap/ldif

if [ ! -e /app/data/ldap/config.ldif ]; then
    cat <<EOF > /app/data/ldap/config.ldif
# use in this file to create service users
# service users can be used for bind requests, but will not be returned in search requests
dn: cn=readonly,{{.BaseDN}}
cn: readonly
description: LDAP read only service user
objectClass: simpleSecurityObject
objectClass: organizationalRole
# password value can be stored in clear text or hashed
# create secure hash by running /opt/libregraph/idm/idmd gen passwd
userPassword: readonly
EOF
fi

exec /opt/libregraph/idm/idmd serve \
    --ldif-config /app/data/ldap/config.ldif \
    --ldif-main /app/data/ldap/ldif/