#!/bin/bash
set -euo pipefail

# define defaults
signing_private_key=${signing_private_key:-"/app/data/openid/signing-private-key.pem"}
validation_keys_path=${validation_keys_path:-"/app/data/openid/validationkeys"}
encryption_secret_key=${encryption_secret_key:-"/app/data/openid/lico-encryption-secret.key"}
identifier_registration_conf=${identifier_registration_conf:-"/app/data/openid/identifier-registration.yaml"}
identifier_scopes_conf=${identifier_scopes_conf:-"/app/data/openid/scopes.yaml"}
identifier_default_banner_logo=${identifier_default_banner_logo:-"/app/data/your-logo.svg"}
identifier_default_sign_in_page_text=${identifier_default_sign_in_page_text:-"Your Identity is your email address!"}
identifier_default_username_hint_text=${identifier_default_username_hint_text:-"Coudron Username"}
ULIMIT_GENERAL=${ULIMIT_GENERAL:-8196}

export LDAP_URI=$CLOUDRON_LDAP_URL
export LDAP_BINDDN=$CLOUDRON_LDAP_BIND_DN
export LDAP_BINDPW=CLOUDRON_LDAP_BIND_PASSWORD
export LDAP_BASEDN=$CLOUDRON_LDAP_USERS_BASE_DN
export LDAP_FILTER="(objectClass=user)"
export LDAP_LOGIN_ATTRIBUTE="username"
export LDAP_NAME_ATTRIBUTE="displayname"

# modify open file limit unless 0 was specified as its value
if [ ! "$ULIMIT_GENERAL" = 0 ]; then
    # set general open file limit
    ulimit -n "$ULIMIT_GENERAL"
fi

if [ ! -e "$identifier_registration_conf" ]; then
    mkdir -p "$(dirname "$identifier_registration_conf")"
    cp /opt/libregraph/lico/identifier-registration.yaml.in "$identifier_registration_conf"
fi

if [ ! -e "$identifier_scopes_conf" ]; then
mkdir -p "$(dirname "$identifier_scopes_conf")"
    cp /opt/libregraph/lico/scopes.yaml.in "$identifier_scopes_conf"
fi

if [ ! -e "$signing_private_key" ]; then
    mkdir -p "${validation_keys_path}"
    rnd=$(RANDFILE=/tmp/.rnd openssl rand -hex 2)
    key="${validation_keys_path}/lico-$(date +%Y%m%d)-${rnd}.pem"
    >&2	echo "setup: creating new RSA private key at ${key} ..."
    RANDFILE=/tmp/.rnd openssl genpkey -algorithm RSA -out "${key}" -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537
    if [ -f "${key}" ]; then
        ln -sn "${key}" "${signing_private_key}"
    fi
fi

if [ ! -e "$encryption_secret_key" ]; then
    >&2	echo "setup: creating new secret key at ${encryption_secret_key} ..."
    RANDFILE=/tmp/.rnd openssl rand -out "${encryption_secret_key}" 32
fi

oidc_issuer_identifier=${oidc_issuer_identifier:-https://$CLOUDRON_APP_DOMAIN}

cd /opt/libregraph/lico/
exec /opt/libregraph/lico/licod serve \
    --signing-private-key="$signing_private_key" \
    --encryption-secret="$encryption_secret_key" \
    --identifier-registration-conf "$identifier_registration_conf" \
    --identifier-scopes-conf "$identifier_scopes_conf" \
    --identifier-default-username-hint-text="$identifier_default_username_hint_text" \
    --iss="$oidc_issuer_identifier" \
    ldap

    #--identifier-default-banner-logo="$identifier_default_banner_logo" \
    #    --identifier-default-sign-in-page-text="$identifier_default_sign_in_page_text" \