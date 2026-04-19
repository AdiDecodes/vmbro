#!/bin/bash

install_node() {
    log_info "Installing NVM + Node.js"

    if [[ -d "$HOME/.nvm" ]]; then
        log_warn "NVM already installed. Skipping."
        return
    fi

    run_safe "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash"
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    run_safe "nvm install --lts"
    log_info "Node installed: $(node -v)"
}
