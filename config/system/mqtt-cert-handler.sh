#!/bin/bash
# mqtt-cert-handler.sh — MQTT TLS certificate management for LoxBerry
# Called by mqtt-handler.pl (runs as root via sudo)
# Usage: mqtt-cert-handler.sh create|revoke|status

MQTT_TLS_DIR="/etc/mosquitto/tls"
CA_KEY="${MQTT_TLS_DIR}/ca.key"
CA_CERT="${MQTT_TLS_DIR}/ca.crt"
SERVER_KEY="${MQTT_TLS_DIR}/server.key"
SERVER_CERT="${MQTT_TLS_DIR}/server.crt"
SERVER_CSR="${MQTT_TLS_DIR}/server.csr"

create_cert() {
    mkdir -p "${MQTT_TLS_DIR}"

    HOSTNAME=$(hostname -f 2>/dev/null || hostname)
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk 'NR==1{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')

    # MQTT-specific CA (independent of the LoxBerry web CA)
    openssl genrsa -out "${CA_KEY}" 2048 2>/dev/null
    CA_EXT_FILE=$(mktemp /tmp/mqtt_ca_ext.XXXXXX)
    cat > "${CA_EXT_FILE}" << 'CAEXTEOF'
[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
CAEXTEOF
    openssl req -new -x509 -days 3650 -key "${CA_KEY}" \
        -out "${CA_CERT}" \
        -subj "/CN=LoxBerry MQTT CA/O=LoxBerry" \
        -extensions v3_ca -extfile "${CA_EXT_FILE}" 2>/dev/null
    rm -f "${CA_EXT_FILE}"

    # Server key — no passphrase, required by Mosquitto
    openssl genrsa -out "${SERVER_KEY}" 2048 2>/dev/null

    # SAN extension config
    EXT_FILE=$(mktemp /tmp/mqtt_ssl_ext.XXXXXX)
    cat > "${EXT_FILE}" << EXTEOF
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no
[req_dn]
CN = ${HOSTNAME}
O = LoxBerry MQTT
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = ${HOSTNAME}
IP.1 = 127.0.0.1
EXTEOF
    [ -n "${LOCAL_IP}" ] && echo "IP.2 = ${LOCAL_IP}" >> "${EXT_FILE}"

    openssl req -new -key "${SERVER_KEY}" \
        -out "${SERVER_CSR}" \
        -config "${EXT_FILE}" 2>/dev/null

    openssl x509 -req -in "${SERVER_CSR}" \
        -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
        -out "${SERVER_CERT}" \
        -days 3650 -sha256 \
        -extfile "${EXT_FILE}" -extensions v3_req 2>/dev/null

    rm -f "${SERVER_CSR}" "${EXT_FILE}"

    chmod 644 "${CA_CERT}" "${SERVER_CERT}"
    chmod 640 "${CA_KEY}" "${SERVER_KEY}"
    # mosquitto service (user: mosquitto) needs to read the key
    chown root:mosquitto "${CA_KEY}" "${SERVER_KEY}" 2>/dev/null || true

    echo '{"success":true}'
}

revoke_cert() {
    if [ ! -f "${SERVER_CERT}" ]; then
        echo '{"success":false,"error":"No certificate found"}'
        exit 0
    fi
    rm -f "${CA_KEY}" "${CA_CERT}" "${SERVER_KEY}" "${SERVER_CERT}" "${SERVER_CSR}"
    echo '{"success":true}'
}

status_cert() {
    if [ ! -f "${SERVER_CERT}" ]; then
        echo '{"exists":false}'
        exit 0
    fi
    EXPIRY=$(openssl x509 -enddate -noout -in "${SERVER_CERT}" 2>/dev/null | cut -d= -f2)
    if openssl x509 -checkend 86400 -noout -in "${SERVER_CERT}" >/dev/null 2>&1; then
        VALID="true"
    else
        VALID="false"
    fi
    printf '{"exists":true,"valid":%s,"expiry":"%s"}\n' "${VALID}" "${EXPIRY}"
}

case "$1" in
    create) create_cert ;;
    revoke) revoke_cert ;;
    status) status_cert ;;
    *) echo '{"success":false,"error":"Unknown action"}'; exit 1 ;;
esac
