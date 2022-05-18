#!/usr/bin/env bash

set -o errexit

CERT_FILE=${1}
KEY_FILE=${2}
SKIP_CERT_CHAIN_CHECK=${3}

if [[ -z "$CERT_FILE" || -z "$KEY_FILE" ]];
then
    >&2 echo "Usage: ssl-checker.sh <path-to-certificate> <path-to-key>"
    >&2 echo "or skip certificate chain check: ssl-checker.sh <path-to-certificate> <path-to-key> --skip-cert-chain-check"
    exit 1
fi

if [ ! -f "$CERT_FILE" ];
then
    >&2 echo "$CERT_FILE: cert file not found"
    exit 1
fi

if ! openssl x509 -noout -modulus -in "$CERT_FILE" > /dev/null; then
    >&2 echo "$CERT_FILE: the certificate (or chain) is not in PEM format"
    exit 1
fi

if [ ! -f "$KEY_FILE" ];
then
    >&2 echo "$KEY_FILE: key file not found"
    exit 1
fi

if ! openssl rsa -noout -modulus -in "$KEY_FILE" > /dev/null; then
    >&2 echo "$KEY_FILE: the key is not RSA or not in PEM format"
    exit 1
fi

CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_FILE")
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_FILE")

if [[ $CERT_MODULUS != "$KEY_MODULUS" ]]; then
    >&2 echo "$KEY_FILE: key file is not compatible with the certificate $CERT_FILE"
    exit 1
fi

# get ssl certificate chain info
PKCS7_CERT=$(openssl crl2pkcs7 -nocrl -certfile "$CERT_FILE")
CERT_CHAIN_INFO=$(echo "$PKCS7_CERT" | openssl pkcs7 -print_certs -noout -text)
IFS=$'\r\n' GLOBIGNORE='*' command eval  'CERTS_SUBJECT_FIELD=($(echo "$CERT_CHAIN_INFO" | grep -E "Subject:" | sed "s/Subject://"))'
IFS=$'\r\n' GLOBIGNORE='*' command eval  'CERTS_ISSUER_FIELD=($(echo "$CERT_CHAIN_INFO" | grep -E "Issuer:" | sed "s/Issuer://"))'
IFS=$'\r\n' GLOBIGNORE='*' command eval  'CERTS_NOT_BEFORE_FIELD=($(echo "$CERT_CHAIN_INFO" | grep -E "Not Before:" | sed "s/Not Before://"))'
IFS=$'\r\n' GLOBIGNORE='*' command eval  'CERTS_NOT_AFTER_FIELD=($(echo "$CERT_CHAIN_INFO" | grep -E "Not After :" | sed "s/Not After ://"))'
COUNT_CERT=${#CERTS_SUBJECT_FIELD[@]}

if [ -n "${SKIP_CERT_CHAIN_CHECK}" ]; then
    >&2 echo "Skip certificate chain check"
    exit 0
fi

# check ssl certificate chain
if [[ $COUNT_CERT == 1 ]]; then
    >&2 echo "error: SSL certificate should have full chain"
    exit 1
fi

declare -A ISSUER_BY_SUBJECT
declare -a SUBJECT_INDEX
for ((i=0; i<=$((COUNT_CERT - 1)); i++)); do
    SUBJECT=${CERTS_SUBJECT_FIELD[$i]}
    ISSUER=${CERTS_ISSUER_FIELD[$i]}
    ISSUER_BY_SUBJECT[$SUBJECT]=$ISSUER
    SUBJECT_INDEX[$i]=$SUBJECT
done

ISSUER=
for INDEX in "${!SUBJECT_INDEX[@]}"; do
    SUBJECT=${SUBJECT_INDEX[$INDEX]}
    if [ -n "${ISSUER}" ] && [ "${SUBJECT}" != "${ISSUER}" ]; then
        >&2 echo "error: Invalid SSL certificate chain."
        exit 1
    fi
    ISSUER=${ISSUER_BY_SUBJECT[$SUBJECT]}
    if [ $((COUNT_CERT - 1)) == "${INDEX}" ] && [ "${SUBJECT}" != "${ISSUER}" ]; then
        >&2 echo "error: Incomplete chain of certificates."
        exit 1
    fi
done

declare -A VALIDITY_CERT_MAP
declare -a VALIDITY_CERT_MAP_INDEX
for ((i=0; i<=$((COUNT_CERT - 1)); i++)); do
    NOT_BEFORE_DATE=$(date -d "${CERTS_NOT_BEFORE_FIELD[$i]}" +%s)
    NOT_AFTER_DATE=$(date -d "${CERTS_NOT_AFTER_FIELD[$i]}" +%s)
    VALIDITY_CERT_MAP[$NOT_BEFORE_DATE]=$NOT_AFTER_DATE
    VALIDITY_CERT_MAP_INDEX[$i]=$NOT_BEFORE_DATE
done

for VALIDITY_CERT_INDEX in "${!VALIDITY_CERT_MAP_INDEX[@]}"; do
    CURRENT_DATE=$(date +%s)
    NOT_BEFORE_DATE=${VALIDITY_CERT_MAP_INDEX[$VALIDITY_CERT_INDEX]}
    if [ "${CURRENT_DATE}" -le "${NOT_BEFORE_DATE}" ]; then
        >&2 echo "error: Certificate '$VALIDITY_CERT_INDEX - ${SUBJECT_INDEX[$VALIDITY_CERT_INDEX]}' with future notBefore date or invalid local date."
        exit 1
    fi
    NOT_AFTER_DATE=${VALIDITY_CERT_MAP[$NOT_BEFORE_DATE]}
    if [ "${CURRENT_DATE}" -ge "${NOT_AFTER_DATE}" ]; then
        >&2 echo "error: SSL certificate '$VALIDITY_CERT_INDEX - ${SUBJECT_INDEX[$VALIDITY_CERT_INDEX]}' expired."
        exit 1
    fi
done

>&2 echo "SSL certificate and key verified successfully."