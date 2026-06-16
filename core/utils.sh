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

_draw_menu() {
    local selected="$1"
    shift
    local options=("$@")
    local i
    for ((i=0; i<${#options[@]}; i++)); do
        if [[ "$i" -eq "$selected" ]]; then
            echo -e "  ${BLUE}❯${RESET} ${options[$i]}"
        else
            echo -e "    ${options[$i]}"
        fi
    done
}

prompt_select() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0

    tput civis 2>/dev/null

    echo ""
    echo -e "  $title"
    echo -e "  ${YELLOW}(↑↓ arrows, j/k, or number to select — Enter to confirm)${RESET}"
    echo ""
    _draw_menu "$selected" "${options[@]}"

    while true; do
        local key seq1 seq2
        IFS= read -rsn1 key 2>/dev/null

        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn1 -t 0.1 seq1 2>/dev/null
            IFS= read -rsn1 -t 0.1 seq2 2>/dev/null
            key="${key}${seq1}${seq2}"
        fi

        local confirm=false
        case "$key" in
            $'\x1b[A'|k|K)
                (( selected = (selected - 1 + count) % count ))
                ;;
            $'\x1b[B'|j|J)
                (( selected = (selected + 1) % count ))
                ;;
            '')
                confirm=true
                ;;
            [1-9])
                local num=$(( key - 1 ))
                if [[ "$num" -lt "$count" ]]; then
                    selected=$num
                    confirm=true
                fi
                ;;
        esac

        if $confirm; then
            tput cnorm 2>/dev/null
            local clear_lines=$(( count + 3 ))
            for ((i=0; i<clear_lines; i++)); do
                tput cuu1 2>/dev/null; tput el 2>/dev/null
            done
            echo -e "  $title"
            echo -e "  ${GREEN}❯${RESET} ${options[$selected]}"
            echo ""
            echo "${options[$selected]}"
            return
        fi

        # Redraw in place
        for ((i=0; i<=count; i++)); do
            tput cuu1 2>/dev/null
        done
        _draw_menu "$selected" "${options[@]}"
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
