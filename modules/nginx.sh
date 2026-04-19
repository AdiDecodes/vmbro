#!/bin/bash

install_nginx() {
    log_info "Installing NGINX..."
    run_safe "apt update"
    run_safe "apt install -y nginx"

    if prompt_yes_no "Do you want to configure a production server block?"; then
        read -p "Enter domain: " DOMAIN
        SITE_FILE="/etc/nginx/sites-available/$DOMAIN"

        cat > "$SITE_FILE" <<EOF
server {
    server_name $DOMAIN;
    root /var/www/$DOMAIN;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

        run_safe "ln -sf $SITE_FILE /etc/nginx/sites-enabled/"
        run_safe "nginx -t"
        run_safe "systemctl restart nginx"
    fi

    log_info "NGINX setup complete."
}
