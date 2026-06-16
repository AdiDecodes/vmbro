#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$BASE_DIR/core"
MODULE_DIR="$BASE_DIR/modules"
LOG_FILE="$BASE_DIR/logs/vmbro.log"

mkdir -p "$BASE_DIR/logs"

# ── Bootstrap: ensure jq is available ────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo "[vmbro] jq not found — installing..."
    apt-get update -qq && apt-get install -y jq >/dev/null 2>&1 \
        || { echo "[vmbro] ERROR: failed to install jq"; exit 1; }
fi

# ── Core ──────────────────────────────────────────────────────────────────────
source "$CORE_DIR/utils.sh"
source "$CORE_DIR/config.sh"
source "$CORE_DIR/commands.sh"

# ── Modules ───────────────────────────────────────────────────────────────────
source "$MODULE_DIR/node.sh"
source "$MODULE_DIR/nginx.sh"
source "$MODULE_DIR/caddy.sh"
source "$MODULE_DIR/docker.sh"
source "$MODULE_DIR/redis.sh"
source "$MODULE_DIR/mongodb.sh"
source "$MODULE_DIR/doctor.sh"
source "$MODULE_DIR/deploy.sh"
source "$MODULE_DIR/secure.sh"
source "$MODULE_DIR/report.sh"
source "$MODULE_DIR/dashboard.sh"
source "$MODULE_DIR/backup.sh"

ensure_root
config_load

CMD="${1:-}"
SUB="${2:-}"

case "$CMD" in

    # ── New commands ────────────────────────────────────────────────────────

    init)
        echo ""
        echo -e "${BLUE}  ██╗   ██╗███╗   ███╗██████╗ ██████╗  ██████╗ ${RESET}"
        echo -e "${BLUE}  ██║   ██║████╗ ████║██╔══██╗██╔══██╗██╔═══██╗${RESET}"
        echo -e "${BLUE}  ██║   ██║██╔████╔██║██████╔╝██████╔╝██║   ██║${RESET}"
        echo -e "${BLUE}  ╚██╗ ██╔╝██║╚██╔╝██║██╔══██╗██╔══██╗██║   ██║${RESET}"
        echo -e "${BLUE}   ╚████╔╝ ██║ ╚═╝ ██║██████╔╝██║  ██║╚██████╔╝${RESET}"
        echo -e "${BLUE}    ╚═══╝  ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ${RESET}"
        echo -e "            ${YELLOW}Your VPS deployment copilot.${RESET}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        choice=$(prompt_select "What are you deploying?" \
            "Node API" \
            "Next.js" \
            "Static Site" \
            "Docker Compose" \
            "Redis" \
            "MongoDB" \
            "Custom (install services)" \
            "Exit")
        case "$choice" in
            "Node API")                 deploy_node ;;
            "Next.js")                  deploy_nextjs ;;
            "Static Site")              _init_static_site ;;
            "Docker Compose")           deploy_docker ;;
            "Redis")                    install_redis_flow ;;
            "MongoDB")                  install_mongo_flow ;;
            "Custom (install services)") _init_custom ;;
            "Exit")                     exit 0 ;;
        esac
        ;;

    doctor)
        run_doctor
        ;;

    deploy)
        case "$SUB" in
            node)   deploy_node   ;;
            nextjs) deploy_nextjs ;;
            docker) deploy_docker ;;
            *)
                echo "Usage: vmbro deploy [node|nextjs|docker]"
                echo ""
                echo "  node    Deploy a Node.js application with systemd + reverse proxy"
                echo "  nextjs  Clone, build, and deploy a Next.js app"
                echo "  docker  Deploy a Dockerfile or docker-compose project"
                ;;
        esac
        ;;

    secure)
        run_secure
        ;;

    report)
        run_report "$SUB"
        ;;

    dashboard)
        run_dashboard
        ;;

    backup)
        run_backup "$SUB"
        ;;

    # ── Existing commands ───────────────────────────────────────────────────

    setup)
        # Kept for backwards compatibility — prefer: vmbro init
        echo -e "${YELLOW}[WARN]${RESET} 'vmbro setup' is deprecated. Use 'vmbro init' instead."
        echo ""
        choice=$(prompt_select "What are you deploying?" \
            "Node API" \
            "Next.js" \
            "Static Site" \
            "Docker Compose" \
            "Redis" \
            "MongoDB" \
            "Custom (install services)" \
            "Exit")
        case "$choice" in
            "Node API")                 deploy_node ;;
            "Next.js")                  deploy_nextjs ;;
            "Static Site")              _init_static_site ;;
            "Docker Compose")           deploy_docker ;;
            "Redis")                    install_redis_flow ;;
            "MongoDB")                  install_mongo_flow ;;
            "Custom (install services)") _init_custom ;;
            "Exit")                     exit 0 ;;
        esac
        ;;

    restart)
        command_restart "$SUB"
        ;;

    status)
        command_status "$SUB"
        ;;

    reset)
        command_reset "$SUB"
        ;;

    config)
        case "$SUB" in
            view) command_config_view ;;
            edit) command_config_edit ;;
            *) echo "Usage: vmbro config [view|edit]" ;;
        esac
        ;;

    logs)
        command_logs "$SUB"
        ;;

    *)
        echo ""
        echo -e "${BLUE}VMBRO — Your VPS deployment copilot${RESET}"
        echo ""
        echo "  Deployment"
        echo "    vmbro init                    Interactive deployment wizard"
        echo "    vmbro deploy node             Deploy a Node.js app"
        echo "    vmbro deploy nextjs           Clone, build, and deploy Next.js"
        echo "    vmbro deploy docker           Deploy Dockerfile / docker-compose"
        echo ""
        echo "  Diagnostics"
        echo "    vmbro doctor                  Full server health check"
        echo "    vmbro report                  Server snapshot (CPU, RAM, Disk, SSL)"
        echo "    vmbro report --json           Machine-readable JSON report"
        echo "    vmbro dashboard               Live terminal dashboard"
        echo ""
        echo "  Security"
        echo "    vmbro secure                  Harden server (UFW, SSH, fail2ban)"
        echo ""
        echo "  Backups"
        echo "    vmbro backup create           Back up MongoDB / Redis / Docker volumes"
        echo "    vmbro backup list             List existing backups"
        echo ""
        echo "  Management"
        echo "    vmbro status [service]        Check service status"
        echo "    vmbro restart [service]       Restart a service"
        echo "    vmbro logs [service]          Tail service logs"
        echo "    vmbro reset [service]         Reset a service to defaults"
        echo "    vmbro config view             View current config"
        echo "    vmbro config edit             Edit config file"
        echo ""
        ;;
esac

# ── Init wizard helpers (defined here to share sourced modules) ───────────────

_init_static_site() {
    read -rp "  Domain: " DOMAIN
    read -rp "  Site directory [/var/www/$DOMAIN]: " SITE_DIR
    SITE_DIR="${SITE_DIR:-/var/www/$DOMAIN}"

    mkdir -p "$SITE_DIR"

    if ! command -v nginx &>/dev/null; then
        log_info "Installing NGINX..."
        run_safe "apt-get update -qq && apt-get install -y nginx"
    fi

    cat > "/etc/nginx/sites-available/$DOMAIN" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $SITE_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

    ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
    run_safe "nginx -t"
    run_safe "systemctl reload nginx"

    if prompt_yes_no "Set up HTTPS with Let's Encrypt for $DOMAIN?"; then
        if ! command -v certbot &>/dev/null; then
            run_safe "apt-get install -y certbot python3-certbot-nginx"
        fi
        run_safe "certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN"
    fi

    log_info "Static site configured at $DOMAIN → $SITE_DIR"
}

_init_custom() {
    while true; do
        choice=$(prompt_select "Choose component to install:" \
            "Node.js" "Nginx" "Caddy" "Docker" "Redis" "MongoDB" "Back")
        case "$choice" in
            "Node.js") install_node       ;;
            "Nginx")   install_nginx      ;;
            "Caddy")   install_caddy      ;;
            "Docker")  install_docker     ;;
            "Redis")   install_redis_flow ;;
            "MongoDB") install_mongo_flow ;;
            "Back")    break              ;;
        esac
    done
}
