#!/bin/bash

# Colors
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; BLUE="\e[36m"; RESET="\e[0m"

log_info()  { echo -e "${BLUE}[INFO]${RESET} $1" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1" | tee -a "$LOG_FILE"; }

ensure_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Run this script using sudo"
        exit 1
    fi
}

prompt_yes_no() {
    read -p "$1 (y/n): " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]]
}

prompt_select() {
    echo ""
    echo "$1"
    shift
    select opt in "$@"; do
        echo "$opt"
        return
    done
}

run_safe() {
    log_info "Running: $1"
    if eval "$1" >>"$LOG_FILE" 2>&1; then
        log_info "Success"
    else
        log_error "Command failed: $1"
        exit 1
    fi
}
