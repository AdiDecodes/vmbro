#!/bin/bash

install_mongo_flow() {
    choice=$(prompt_select "Choose MongoDB installation:" \
        "Local MongoDB Community" \
        "Docker MongoDB" \
        "Use Atlas (no local install)" \
        "Cancel")

    case "$choice" in
        "Local MongoDB Community") install_mongo_local ;;
        "Docker MongoDB") install_mongo_docker ;;
        *) return ;;
    esac
}

install_mongo_local() {
    log_info "Installing MongoDB Community..."
    
    run_safe "apt install -y gnupg curl"
    curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb.gpg

    echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/ubuntu \
$(lsb_release -cs)/mongodb-org/6.0 multiverse" \
    | tee /etc/apt/sources.list.d/mongodb-org-6.0.list

    run_safe "apt update"
    run_safe "apt install -y mongodb-org"
    run_safe "systemctl enable mongod --now"

    log_info "MongoDB installed."
}

install_mongo_docker() {
    log_info "Running Mongo in Docker..."
    run_safe "docker run -d --name mongodb -p 27017:27017 --restart unless-stopped mongo:latest"
}
