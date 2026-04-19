#!/bin/bash

command_restart() {
    svc="$1"

    case "$svc" in
        nginx)
            systemctl restart nginx && log_info "NGINX restarted."
            ;;
        docker)
            systemctl restart docker && log_info "Docker restarted."
            ;;
        redis)
            systemctl restart redis-server && log_info "Redis restarted."
            ;;
        mongo)
            systemctl restart mongod && log_info "MongoDB restarted."
            ;;
        all)
            for s in nginx docker redis-server mongod; do
                systemctl restart "$s" 2>/dev/null
            done
            log_info "All services restarted."
            ;;
        *)
            log_error "Unknown service '$svc'"
            ;;
    esac
}

command_status() {
    svc="$1"

    if [[ -z "$svc" ]]; then
        systemctl --type=service --state=running | grep -E 'nginx|docker|redis|mongo'
    else
        systemctl status "$svc"
    fi
}

command_reset() {
    svc="$1"

    case "$svc" in
        nginx)
            rm -rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*
            systemctl restart nginx
            log_warn "NGINX reset to default."
            ;;
        redis)
            docker rm -f redis 2>/dev/null || true
            apt purge -y redis-server 2>/dev/null || true
            log_warn "Redis reset."
            ;;
        docker)
            docker stop $(docker ps -q) 2>/dev/null || true
            docker system prune -af
            log_warn "Docker cleaned."
            ;;
        mongo)
            rm -rf /var/lib/mongodb/*
            systemctl restart mongod
            log_warn "MongoDB data wiped."
            ;;
        all)
            log_warn "Resetting entire environment…"
            command_reset nginx
            command_reset redis
            command_reset docker
            command_reset mongo
            ;;
        *)
            log_error "Unknown service '$svc'"
            ;;
    esac
}

command_config_view() {
    log_info "Configuration:"
    config_view
}

command_config_edit() {
    nano "$CONFIG_FILE"
}

command_logs() {
    svc="$1"
    journalctl -u "$svc" -n 50 --no-pager
}
