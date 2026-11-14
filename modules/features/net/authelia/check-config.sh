#!/usr/bin/env bash
set -euo pipefail

authelia_bin="@AUTHELIA_BIN@"
openssl_bin="@OPENSSL_BIN@"
config_file="@CONFIG_FILE@"
oidc_jwks_file="@OIDC_JWKS_FILE@"
cookie_domain="@COOKIE_DOMAIN@"
creds_dir="@CREDS_DIR@"
state_dir="@STATE_DIR@"
enable_oidc="@ENABLE_OIDC@"
out_path="$1"

mkdir -p "$TMPDIR/creds" "$TMPDIR/state"
printf '%s' '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' >"$TMPDIR/creds/jwt"
printf '%s' 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210' >"$TMPDIR/creds/storage"
printf '%s' 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789' >"$TMPDIR/creds/session"
printf '%s' '9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba' >"$TMPDIR/creds/hmac"
# shellcheck disable=SC2016
printf '%s' '$pbkdf2-sha512$310000$c2FsdHNhbHRzYWx0c2FsdA$aGFzaGhhc2hoYXNoaGFzaGhhc2hoYXNoaGFzaGhhc2hoYXNoaGFzaGhhc2hoYXNoaGFzaGhhc2hoYXNoaGFzaA' >"$TMPDIR/creds/headscaleClientSecretHash"
"$openssl_bin" genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$TMPDIR/creds/oidcIssuerPrivateKeyFile" 2>/dev/null

# shellcheck disable=SC2016
argon_hash='$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHRzYWx0c2FsdA$aGFzaGhhc2hoYXNoaGFzaGhhc2hoYXNoaGFzaGhhc2g'
cat >"$TMPDIR/creds/users.yml" <<EOF
users:
  testuser:
    displayname: "testuser"
    email: "testuser@${cookie_domain}"
    password: "${argon_hash}"
    groups:
      - devs
EOF

sed \
  -e "s|${creds_dir}|${TMPDIR}/creds|g" \
  -e "s|${state_dir}|${TMPDIR}/state|g" \
  "$config_file" >"$TMPDIR/config.yml"

export CREDENTIALS_DIRECTORY="$TMPDIR/creds"
export AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE="$TMPDIR/creds/jwt"
export AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE="$TMPDIR/creds/storage"
export AUTHELIA_SESSION_SECRET_FILE="$TMPDIR/creds/session"

config_arg="$TMPDIR/config.yml"
if [[ $enable_oidc == "true" ]]; then
  export X_AUTHELIA_CONFIG_FILTERS="template"
  export AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE="$TMPDIR/creds/hmac"
  config_arg="${config_arg},${oidc_jwks_file}"
fi

"$authelia_bin" validate-config --config "$config_arg"
touch "$out_path"
