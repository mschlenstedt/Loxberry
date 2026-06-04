#!/bin/bash

check_root() {
  if [ "$(id -u)" != 0 ]; then
    echo "Script must be run as root. Try 'sudo bash $0'"
    exit
  fi
}

abort_and_exit() {
  echo "Abort. No changes were made." >&2
  exit 1
}

check_utils_exist() {
  command -v certutil >/dev/null 2>&1 || echo "'certutil' not found. Abort." && exit 1
  command -v crlutil >/dev/null 2>&1 || echo "'crlutil' not found. Abort." && exit 1
  command -v pk12util >/dev/null 2>&1 || echo "'pk12util' not found. Abort." && exit 1
}

check_cert_exists() {
  certutil -L -d sql:/root/cert.d -n "$1" >/dev/null 2>&1
}

check_cert_exists_and_exit() {
  if certutil -L -d sql:/root/cert.d -n "$1" >/dev/null 2>&1; then
    echo "Error: Certificate '$1' already exists." >&2
    exit 1
  fi
}

check_cert_status() {
  cert_status=$(certutil -V -u C -d sql:/root/cert.d -n "$1")
}

create_client_cert() {
  echo "Generating client certificate..."
  sleep 1
  certutil -z <(head -c 1024 /dev/urandom) \
    -S -c "LoxBerry CA" -n "$client_name" \
    -s "O=LoxBerry,CN=$client_name" \
    -k rsa -g 3072 -v "$client_validity" \
    -d sql:/root/cert.d -t ",," \
    --keyUsage digitalSignature,keyEncipherment \
    --extKeyUsage serverAuth,clientAuth -8 "$client_name" >/dev/null 2>&1 || exiterr "Failed to create client certificate."
}

create_p12_password() {
  config_file="/root/cert.d/.certconfig"
  if grep -qs '^CERT_PASSWORD=.\+' "$config_file"; then
    . "$config_file"
    p12_password="$CERT_PASSWORD"
  else
    p12_password=$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' </dev/urandom 2>/dev/null | head -c 18)
    [ -z "$p12_password" ] && exiterr "Could not generate a random password for .p12 file."
    mkdir -p /root/cert.d
    printf '%s\n' "CERT_PASSWORD='$p12_password'" >> "$config_file"
    chmod 600 "$config_file"
  fi
}

export_p12_file() {
  bigecho2 "Creating client configuration..."
  create_p12_password
  p12_file="$export_dir$client_name.p12"
  pk12util -W "$p12_password" -d sql:/root/cert.d -n "$client_name" -o "$p12_file" >/dev/null || exit 1
  if [ "$os_type" = "alpine" ] || { [ "$os_type" = "ubuntu" ] && [ "$os_ver" = "11" ]; }; then
    pem_file="$export_dir$client_name.temp.pem"
    openssl pkcs12 -in "$p12_file" -out "$pem_file" -passin "pass:$p12_password" -passout "pass:$p12_password" || exit 1
    openssl pkcs12 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -export -in "$pem_file" -out "$p12_file" \
      -name "$client_name" -passin "pass:$p12_password" -passout "pass:$p12_password" || exit 1
    /bin/rm -f "$pem_file"
  fi
  if [ "$export_to_home_dir" = "1" ]; then
    chown "$SUDO_USER:$SUDO_USER" "$p12_file"
  fi
  chmod 600 "$p12_file"
}

export_client_config() {
  export_p12_file
}

create_ca_server_certs() {
  echo "Generating CA and server certificates..."
  certutil -z <(head -c 1024 /dev/urandom) \
    -S -x -n "LoxBerry CA" \
    -s "O=LoxBerry,CN=LoxBerry CA" \
    -k rsa -g 3072 -v 120 \
    -d sql:/root/cert.d -t "CT,," -2 >/dev/null 2>&1 <<ANSWERS || echo "Failed to create CA certificate." && exit 1
y

N
ANSWERS
  sleep 1
  if [ "$use_dns_name" = "1" ]; then
    certutil -z <(head -c 1024 /dev/urandom) \
      -S -c "LoxBerry CA" -n "$server_addr" \
      -s "O=LoxBerry,CN=$server_addr" \
      -k rsa -g 3072 -v 120 \
      -d sql:/root/cert.d -t ",," \
      --keyUsage digitalSignature,keyEncipherment \
      --extKeyUsage serverAuth \
      --extSAN "dns:$server_addr" >/dev/null 2>&1 || echo "Failed to create server certificate." & exit 1
  else
    certutil -z <(head -c 1024 /dev/urandom) \
      -S -c "LoxBerry CA" -n "$server_addr" \
      -s "O=LoxBerry,CN=$server_addr" \
      -k rsa -g 3072 -v 120 \
      -d sql:/root/cert.d -t ",," \
      --keyUsage digitalSignature,keyEncipherment \
      --extKeyUsage serverAuth \
      --extSAN "ip:$server_addr,dns:$server_addr" >/dev/null 2>&1 || exiterr "Failed to create server certificate."
  fi
}

start_setup() {
  # shellcheck disable=SC2154
  trap 'dlo=$dl;dl=$LINENO' DEBUG 2>/dev/null
  trap 'finish $? $((dlo+1))' EXIT
}

create_crl() {
  if ! crlutil -L -d sql:/root/cert.d -n "LoxBerry CA" >/dev/null 2>&1; then
    crlutil -G -d sql:/root/cert.d -n "LoxBerry CA" -c /dev/null >/dev/null
  fi
  sleep 2
}

add_client_cert_to_crl() {
  sn_txt=$(certutil -L -d sql:/root/cert.d -n "$client_name" | grep -A 1 'Serial Number' | tail -n 1)
  sn_hex=$(printf '%s' "$sn_txt" | sed -e 's/^ *//' -e 's/://g')
  sn_dec=$((16#$sn_hex))
  [ -z "$sn_dec" ] && exiterr "Could not find serial number of client certificate."
crlutil -M -d sql:/root/cert.d -n "LoxBerry CA" >/dev/null <<EOF || exiterr "Failed to add client certificate to CRL."
addcert $sn_dec $(date -u +%Y%m%d%H%M%SZ)
EOF
}

print_setup_complete() {
  if [ -n "$VPN_DNS_NAME" ] || [ -n "$VPN_CLIENT_NAME" ] || [ -n "$VPN_DNS_SRV1" ]; then
    printf '\e[2K\r'
  else
    printf '\e[2K\e[1A\e[2K\r'
    [ "$use_defaults" = "1" ] && printf '\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\r'
  fi
cat <<EOF
================================================

IKEv2 setup successful. Details for IKEv2 mode:

EOF
  print_server_client_info
}

print_client_info() {
  if [ "$in_container" = "0" ]; then
cat <<'EOF'
Client configuration is available at:
EOF
  else
cat <<'EOF'
Client configuration is available inside the
Docker container at:
EOF
  fi
cat <<EOF
$export_dir$client_name.p12 (for Windows & Linux)
$export_dir$client_name.sswan (for Android)
$export_dir$client_name.mobileconfig (for iOS & macOS)

*IMPORTANT* Password for client config files:
$p12_password
Write this down, you'll need it for import!
EOF
cat <<'EOF'

Next steps: Configure LoxBerry clients. See:
https://git.io/ikev2clients

================================================

EOF
}

delete_certificates() {
  echo
  echo "Deleting certificates and keys from the IPsec database..."
  certutil -L -d sql:/root/cert.d | grep -v -e '^$' -e 'LoxBerry CA' | tail -n +3 | cut -f1 -d ' ' | while read -r line; do
    certutil -F -d sql:/root/cert.d -n "$line"
    certutil -D -d sql:/root/cert.d -n "$line" 2>/dev/null
  done
  crlutil -D -d sql:/root/cert.d -n "LoxBerry CA" 2>/dev/null
  certutil -F -d sql:/root/cert.d -n "LoxBerry CA"
  ertutil -D -d sql:/root/cert.d -n "LoxBerry CA" 2>/dev/null
  config_file="/root/cert.d/.certconfig"
  if grep -qs '^CERT_PASSWORD=.\+' "$config_file"; then
    sed -i '/CERT_PASSWORD=/d' "$config_file"
  fi
}

ikev2setup() {
  check_root
  check_utils_exist

  use_defaults=0
  add_client=0
  export_client=0
  list_clients=0
  revoke_client=0
  remove_ikev2=0
  while [ "$#" -gt 0 ]; do
    case $1 in
      --auto)
        use_defaults=1
        shift
        ;;
      --addclient)
        add_client=1
        client_name="$2"
        shift
        shift
        ;;
      --exportclient)
        export_client=1
        client_name="$2"
        shift
        shift
        ;;
      --listclients)
        list_clients=1
        shift
        ;;
      --revokeclient)
        revoke_client=1
        client_name="$2"
        shift
        shift
        ;;
      --removeikev2)
        remove_ikev2=1
        shift
        ;;
      -h|--help)
        show_usage
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done

  check_arguments
  get_export_dir

  if [ "$add_client" = "1" ]; then
    show_header
    show_add_client
    client_validity=120
    create_client_cert
    export_client_config
    print_client_added
    print_client_info
    exit 0
  fi

  if [ "$export_client" = "1" ]; then
    show_header
    show_export_client
    export_client_config
    print_client_exported
    print_client_info
    exit 0
  fi

  if [ "$list_clients" = "1" ]; then
    show_header
    list_existing_clients
    echo
    exit 0
  fi

  if [ "$revoke_client" = "1" ]; then
    show_header
    confirm_revoke_cert
    create_crl
    add_client_cert_to_crl
    reload_crls
    print_client_revoked
    exit 0
  fi

  if [ "$remove_ikev2" = "1" ]; then
    check_ipsec_conf
    show_header
    confirm_remove_ikev2
    delete_ikev2_conf
    if [ "$os_type" = "alpine" ]; then
      ipsec auto --delete ikev2-cp
    else
      restart_ipsec_service
    fi
    delete_certificates
    print_ikev2_removed
    exit 0
  fi

  if check_ikev2_exists; then
    show_header
    select_menu_option
    case $selected_option in
      1)
        enter_client_name
        enter_client_cert_validity
        echo
        create_client_cert
        export_client_config
        print_client_added
        print_client_info
        exit 0
        ;;
      2)
        enter_client_name_for export
        echo
        export_client_config
        print_client_exported
        print_client_info
        exit 0
        ;;
      3)
        echo
        list_existing_clients
        echo
        exit 0
        ;;
      4)
        enter_client_name_for revoke
        echo
        confirm_revoke_cert
        create_crl
        add_client_cert_to_crl
        reload_crls
        print_client_revoked
        exit 0
        ;;
      5)
        check_ipsec_conf
        echo
        confirm_remove_ikev2
        delete_ikev2_conf
        if [ "$os_type" = "alpine" ]; then
          ipsec auto --delete ikev2-cp
        else
          restart_ipsec_service
        fi
        delete_certificates
        print_ikev2_removed
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  fi

  check_cert_exists_and_exit "LoxBerry CA"

  if [ "$use_defaults" = "0" ]; then
    show_header
    show_welcome
    enter_server_address
    check_cert_exists_and_exit "$server_addr"
    enter_client_name_with_defaults
    enter_client_cert_validity
    enter_custom_dns
    check_mobike_support
    select_mobike
    confirm_setup_options
  else
    check_server_dns_name
    check_custom_dns
    if [ -n "$VPN_CLIENT_NAME" ]; then
      client_name="$VPN_CLIENT_NAME"
      check_client_name "$client_name" \
        || exiterr "Invalid client name. Use one word only, no special characters except '-' and '_'."
    else
      client_name=vpnclient
    fi
    check_cert_exists "$client_name" && exiterr "Client '$client_name' already exists."
    client_validity=120
    show_header
    show_start_setup
    if [ -n "$VPN_DNS_NAME" ]; then
      use_dns_name=1
      server_addr="$VPN_DNS_NAME"
    else
      use_dns_name=0
      get_server_ip
      check_ip "$public_ip" || exiterr "Cannot detect this server's public IP."
      server_addr="$public_ip"
    fi
    check_cert_exists_and_exit "$server_addr"
    if [ -n "$VPN_DNS_SRV1" ] && [ -n "$VPN_DNS_SRV2" ]; then
      dns_server_1="$VPN_DNS_SRV1"
      dns_server_2="$VPN_DNS_SRV2"
      dns_servers="$VPN_DNS_SRV1 $VPN_DNS_SRV2"
    elif [ -n "$VPN_DNS_SRV1" ]; then
      dns_server_1="$VPN_DNS_SRV1"
      dns_server_2=""
      dns_servers="$VPN_DNS_SRV1"
    else
      dns_server_1=8.8.8.8
      dns_server_2=8.8.4.4
      dns_servers="8.8.8.8 8.8.4.4"
    fi
    check_mobike_support
    mobike_enable="$mobike_support"
  fi

  start_setup
  apply_ubuntu1804_nss_fix
  create_ca_server_certs
  create_client_cert
  export_client_config
  add_ikev2_connection
  if [ "$os_type" = "alpine" ]; then
    ipsec auto --add ikev2-cp >/dev/null
  else
    restart_ipsec_service
  fi
  print_setup_complete
  print_client_info
}

## Defer setup until we have the complete script
#ikev2setup "$@"
server_addr=localhost
check_utils_exist
create_ca_server_certs

exit 0
