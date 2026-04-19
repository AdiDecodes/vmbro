#!/bin/bash

install_docker() {
    log_info "Installing Docker..."

    run_safe "apt update"
    run_safe "apt install -y ca-certificates curl gnupg"
    run_safe "install -m 0755 -d /etc/apt/keyrings"

    run_safe "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    run_safe "chmod a+r /etc/apt/keyrings/docker.gpg"

    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

    run_safe "apt update"
    run_safe "apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

    log_info "Docker installed."
}
