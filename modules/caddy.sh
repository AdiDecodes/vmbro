#!/bin/bash

install_caddy() {
    log_info "Installing Caddy..."
    run_safe "apt install -y debian-keyring debian-archive-keyring apt-transport-https"
    run_safe "curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | apt-key add -"
    run_safe "curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | tee /etc/apt/sources.list.d/caddy-stable.list"
    run_safe "apt update && apt install -y caddy"

    if prompt_yes_no "Set up a domain with HTTPS?"; then
        read -p "Enter domain: " DOMAIN
        CADDYFILE="/etc/caddy/Caddyfile"

        cat > "$CADDYFILE" <<EOF
$DOMAIN {
    root * /var/www/$DOMAIN
    file_server
    encode gzip
}
EOF

        run_safe "systemctl restart caddy"
    fi

    log_info "Caddy installed."
}
