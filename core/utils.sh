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
    local i
    local options=("$@")
    for ((i=0; i<${#options[@]}; i++)); do
        if [[ "$i" -eq "$selected" ]]; then
            echo -e "  ${BLUE}❯${RESET} ${options[$i]}" >&2
        else
            echo -e "    ${options[$i]}" >&2
        fi
    done
}

prompt_select() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0
    local i

    tput civis > /dev/tty 2>/dev/null

    # Print header + initial menu to stderr so it shows even inside $(...)
    echo "" >&2
    echo -e "  $title" >&2
    echo -e "  ${YELLOW}Use ↑↓ arrows or j/k to move, number to jump, Enter to confirm${RESET}" >&2
    echo "" >&2
    _draw_menu "$selected" "${options[@]}"

    while true; do
        local key seq1 seq2
        IFS= read -rsn1 key < /dev/tty

        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn1 -t 0.1 seq1 < /dev/tty
            IFS= read -rsn1 -t 0.1 seq2 < /dev/tty
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
            tput cnorm > /dev/tty 2>/dev/null
            # Clear the menu (header=4 lines + option lines)
            local clear_lines=$(( count + 4 ))
            for ((i=0; i<clear_lines; i++)); do
                tput cuu1 > /dev/tty 2>/dev/null
                tput el   > /dev/tty 2>/dev/null
            done
            echo -e "  $title" >&2
            echo -e "  ${GREEN}❯${RESET} ${options[$selected]}" >&2
            echo "" >&2
            # Only the result goes to stdout — captured by $()
            echo "${options[$selected]}"
            return
        fi

        # Redraw menu in place: move up (count) option lines
        for ((i=0; i<count; i++)); do
            tput cuu1 > /dev/tty 2>/dev/null
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
