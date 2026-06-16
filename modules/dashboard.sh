#!/bin/bash

_dashboard_bar() {
    local label="$1"
    local pct="${2:-0}"
    local bar_len=28
    local filled=$(( pct * bar_len / 100 ))
    local empty=$(( bar_len - filled ))

    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done

    local color
    if   [[ "$pct" -ge 85 ]]; then color="$RED"
    elif [[ "$pct" -ge 60 ]]; then color="$YELLOW"
    else                            color="$GREEN"
    fi

    printf "  %-4s  [%b%s%b]  %3d%%\n" "$label" "$color" "$bar" "$RESET" "$pct"
}

run_dashboard() {
    local REFRESH=3

    # Hide cursor; restore on exit
    tput civis 2>/dev/null || true
    trap 'tput cnorm 2>/dev/null; echo ""; exit 0' INT TERM

    while true; do
        clear

        local cpu_cores load_avg load_pct
        cpu_cores=$(nproc 2>/dev/null || echo 1)
        load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")
        load_pct=$(awk "BEGIN {v=$load_avg/$cpu_cores*100; if(v>100)v=100; printf \"%.0f\", v}")

        local mem_total mem_used mem_pct
        mem_total=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
        mem_used=$(free -m  2>/dev/null | awk '/Mem:/ {print $3}')
        mem_pct=$(free      2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2*100}')

        local disk_pct
        disk_pct=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

        local uptime_str
        uptime_str=$(uptime -p 2>/dev/null || uptime)

        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${BLUE}  VMBRO Dashboard${RESET}  $(hostname)  │  $timestamp"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""

        _dashboard_bar "CPU"  "${load_pct:-0}"
        _dashboard_bar "MEM"  "${mem_pct:-0}"
        _dashboard_bar "DISK" "${disk_pct:-0}"
        echo -e "  Memory: ${mem_used:-?}MB / ${mem_total:-?}MB    Uptime: $uptime_str"
        echo ""

        echo -e "${BLUE}Services${RESET}"
        for svc in nginx caddy docker redis-server mongod; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                echo -e "  ${GREEN}●${RESET} $svc"
            elif systemctl list-units --all --quiet "$svc" 2>/dev/null | grep -q "$svc"; then
                echo -e "  ${RED}●${RESET} $svc  (inactive)"
            fi
        done
        echo ""

        # Docker containers (only if Docker is running)
        if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
            local containers
            containers=$(docker ps --format "{{.Status}}\t{{.Names}}\t{{.Image}}" 2>/dev/null)
            if [[ -n "$containers" ]]; then
                echo -e "${BLUE}Docker Containers${RESET}"
                while IFS=$'\t' read -r status name image; do
                    if [[ "$status" == Up* ]]; then
                        echo -e "  ${GREEN}●${RESET} $name  ($image)  $status"
                    else
                        echo -e "  ${RED}●${RESET} $name  ($image)  $status"
                    fi
                done <<< "$containers"
                echo ""
            fi
        fi

        echo -e "${YELLOW}  Press Ctrl+C to exit  │  Refreshing every ${REFRESH}s${RESET}"
        sleep "$REFRESH"
    done
}
