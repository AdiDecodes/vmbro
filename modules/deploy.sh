#!/bin/bash

# ─── Helpers ────────────────────────────────────────────────────────────────

_ensure_node() {
    if command -v node &>/dev/null; then
        log_info "Node.js already installed: $(node -v)"
        return
    fi
    # Try loading from nvm
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck source=/dev/null
        source "$NVM_DIR/nvm.sh"
    fi
    if ! command -v node &>/dev/null; then
        log_info "Node.js not found — installing via NVM..."
        source "$MODULE_DIR/node.sh"
        install_node
        export NVM_DIR="$HOME/.nvm"
        # shellcheck source=/dev/null
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    fi
}

_configure_nginx_proxy() {
    local domain="$1"
    local port="$2"

    if ! command -v nginx &>/dev/null; then
        log_info "Installing NGINX..."
        run_safe "apt-get update -qq && apt-get install -y nginx"
    fi

    local site_file="/etc/nginx/sites-available/$domain"
    cat > "$site_file" <<EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    ln -sf "$site_file" "/etc/nginx/sites-enabled/$domain"
    run_safe "nginx -t"
    run_safe "systemctl reload nginx"
    log_info "NGINX reverse proxy configured: $domain → port $port"
}

_setup_ssl() {
    local domain="$1"

    if ! command -v certbot &>/dev/null; then
        log_info "Installing Certbot..."
        run_safe "apt-get install -y certbot python3-certbot-nginx"
    fi
    run_safe "certbot --nginx -d $domain --non-interactive --agree-tos -m admin@$domain"
    log_info "SSL configured for $domain"
}

_open_firewall_http() {
    if command -v ufw &>/dev/null; then
        ufw allow 80/tcp  >/dev/null 2>&1 || true
        ufw allow 443/tcp >/dev/null 2>&1 || true
    fi
}

# ─── deploy node ─────────────────────────────────────────────────────────────

deploy_node() {
    log_info "Deploying Node.js application..."
    echo ""

    read -rp "  App name (used for systemd service): " APP_NAME
    read -rp "  App directory (absolute path): " APP_DIR
    read -rp "  Entry point (e.g. index.js): " ENTRY_POINT
    read -rp "  Port your app listens on [3000]: " APP_PORT
    APP_PORT="${APP_PORT:-3000}"
    read -rp "  Domain (leave blank to skip reverse proxy): " DOMAIN

    if [[ -z "$APP_NAME" || -z "$APP_DIR" || -z "$ENTRY_POINT" ]]; then
        log_error "App name, directory, and entry point are required."
        return 1
    fi

    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Directory not found: $APP_DIR"
        return 1
    fi

    _ensure_node
    local NODE_BIN
    NODE_BIN=$(command -v node 2>/dev/null)

    # Install npm dependencies
    if [[ -f "$APP_DIR/package.json" ]]; then
        log_info "Installing npm dependencies..."
        run_safe "cd $APP_DIR && npm install --production"
    fi

    # Create systemd service
    log_info "Creating systemd service: $APP_NAME"
    cat > "/etc/systemd/system/${APP_NAME}.service" <<EOF
[Unit]
Description=$APP_NAME Node.js Application
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$NODE_BIN $APP_DIR/$ENTRY_POINT
Restart=always
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    run_safe "systemctl daemon-reload"
    run_safe "systemctl enable $APP_NAME"
    run_safe "systemctl start $APP_NAME"

    _open_firewall_http

    if [[ -n "$DOMAIN" ]]; then
        _configure_nginx_proxy "$DOMAIN" "$APP_PORT"
        if prompt_yes_no "Set up HTTPS with Let's Encrypt for $DOMAIN?"; then
            _setup_ssl "$DOMAIN"
        fi
    fi

    echo ""
    log_info "Node.js app '$APP_NAME' deployed successfully."
    systemctl status "$APP_NAME" --no-pager 2>/dev/null || true
}

# ─── deploy nextjs ───────────────────────────────────────────────────────────

deploy_nextjs() {
    log_info "Deploying Next.js application..."
    echo ""

    read -rp "  Repository URL: " REPO_URL
    read -rp "  Domain: " DOMAIN
    read -rp "  Branch [main]: " BRANCH
    BRANCH="${BRANCH:-main}"

    if [[ -z "$REPO_URL" || -z "$DOMAIN" ]]; then
        log_error "Repository URL and domain are required."
        return 1
    fi

    local APP_NAME
    APP_NAME=$(basename "$REPO_URL" .git)
    local APP_DIR="/var/www/$APP_NAME"

    _ensure_node
    local NODE_BIN
    NODE_BIN=$(command -v node 2>/dev/null)

    # Ensure git is installed
    if ! command -v git &>/dev/null; then
        run_safe "apt-get install -y git"
    fi

    # Clone or update
    if [[ -d "$APP_DIR/.git" ]]; then
        log_info "Directory exists — pulling latest from $BRANCH..."
        run_safe "git -C $APP_DIR fetch origin"
        run_safe "git -C $APP_DIR checkout $BRANCH"
        run_safe "git -C $APP_DIR pull origin $BRANCH"
    else
        run_safe "git clone --branch $BRANCH $REPO_URL $APP_DIR"
    fi

    # Install dependencies
    log_info "Installing dependencies..."
    run_safe "cd $APP_DIR && npm install"

    # Build
    log_info "Building Next.js application..."
    run_safe "cd $APP_DIR && npm run build"

    # Create systemd service
    log_info "Creating systemd service: $APP_NAME"
    cat > "/etc/systemd/system/${APP_NAME}.service" <<EOF
[Unit]
Description=$APP_NAME Next.js Application
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$NODE_BIN $APP_DIR/node_modules/.bin/next start
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    run_safe "systemctl daemon-reload"
    run_safe "systemctl enable $APP_NAME"
    run_safe "systemctl start $APP_NAME"

    _open_firewall_http
    _configure_nginx_proxy "$DOMAIN" "3000"

    if prompt_yes_no "Set up HTTPS with Let's Encrypt for $DOMAIN?"; then
        _setup_ssl "$DOMAIN"
    fi

    echo ""
    log_info "Next.js app '$APP_NAME' deployed at http${DOMAIN:+s}://$DOMAIN"
    systemctl status "$APP_NAME" --no-pager 2>/dev/null || true
}

# ─── deploy docker ───────────────────────────────────────────────────────────

deploy_docker() {
    log_info "Deploying Docker project..."
    echo ""

    read -rp "  Project directory (absolute path): " PROJECT_DIR

    if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
        log_error "Directory not found: $PROJECT_DIR"
        return 1
    fi

    # Ensure Docker is installed
    if ! command -v docker &>/dev/null; then
        log_info "Docker not found — installing..."
        source "$MODULE_DIR/docker.sh"
        install_docker
    fi

    # Auto-detect compose file
    local compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yaml compose.yml; do
        if [[ -f "$PROJECT_DIR/$f" ]]; then
            compose_file="$f"
            break
        fi
    done

    if [[ -n "$compose_file" ]]; then
        log_info "Detected: Docker Compose ($compose_file)"
        run_safe "cd $PROJECT_DIR && docker compose -f $compose_file up -d --build"
    elif [[ -f "$PROJECT_DIR/Dockerfile" ]]; then
        log_info "Detected: Dockerfile"
        read -rp "  Image/container name: " IMG_NAME
        read -rp "  Port mapping (e.g. 3000:3000): " PORT_MAP
        if [[ -z "$IMG_NAME" ]]; then
            log_error "Image name is required."
            return 1
        fi
        run_safe "cd $PROJECT_DIR && docker build -t $IMG_NAME ."
        run_safe "docker rm -f $IMG_NAME 2>/dev/null; docker run -d --name $IMG_NAME --restart unless-stopped -p $PORT_MAP $IMG_NAME"
    else
        log_error "No Dockerfile or docker-compose file found in $PROJECT_DIR"
        return 1
    fi

    echo ""
    log_info "Docker deployment complete."
    docker ps --filter "status=running" --format "  ● {{.Names}}  {{.Image}}  ({{.Status}})" 2>/dev/null || true
}
