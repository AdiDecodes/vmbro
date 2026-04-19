#!/bin/bash

install_redis_flow() {
    choice=$(prompt_select "Choose Redis installation:" \
        "Local OS package" \
        "Docker container" \
        "Cancel")

    case "$choice" in
        "Local OS package")
            install_redis_local
            ;;
        "Docker container")
            install_redis_docker
            ;;
        *)
            return
            ;;
    esac
}

install_redis_local() {
    log_info "Installing Redis locally..."
    run_safe "apt update && apt install -y redis-server"
    run_safe "systemctl enable redis-server --now"
}

install_redis_docker() {
    log_info "Running Redis via Docker..."
    run_safe "docker run -d --name redis --restart unless-stopped -p 6379:6379 redis:latest"
}
