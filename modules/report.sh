#!/bin/bash

run_report() {
    local json_output=false
    [[ "$1" == "--json" ]] && json_output=true

    # ── Collect metrics ──────────────────────────────────────────────────
    local cpu_cores load_avg
    cpu_cores=$(nproc 2>/dev/null || echo 0)
    load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")

    local mem_total mem_used mem_pct
    mem_total=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
    mem_used=$(free -m  2>/dev/null | awk '/Mem:/ {print $3}')
    mem_pct=$(free      2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2*100}')

    local disk_total disk_used disk_pct
    disk_total=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
    disk_used=$(df -h  / 2>/dev/null | awk 'NR==2 {print $3}')
    disk_pct=$(df      / 2>/dev/null | awk 'NR==2 {print $5}')

    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || uptime)

    # ── JSON output ───────────────────────────────────────────────────────
    if $json_output; then
        local svcs_json=""
        for svc in nginx caddy docker redis-server mongod; do
            local status="inactive"
            systemctl is-active --quiet "$svc" 2>/dev/null && status="active"
            svcs_json+="\"$svc\": \"$status\","
        done
        svcs_json="${svcs_json%,}"

        local open_ports
        open_ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' \
            | grep -oP ':\K\d+' | sort -un | paste -sd ',' - || echo "")

        local cert_json=""
        for cert in /etc/letsencrypt/live/*/cert.pem; do
            if [[ -f "$cert" ]]; then
                local domain expiry days_left
                domain=$(echo "$cert" | grep -oP 'live/\K[^/]+')
                expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
                days_left=$(( ( $(date -d "$expiry" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))
                cert_json+="\"$domain\": ${days_left:-0},"
            fi
        done
        cert_json="${cert_json%,}"

        cat <<EOF
{
  "cpu":    { "cores": $cpu_cores, "load_avg": $load_avg },
  "memory": { "total_mb": ${mem_total:-0}, "used_mb": ${mem_used:-0}, "percent": ${mem_pct:-0} },
  "disk":   { "total": "${disk_total:-?}", "used": "${disk_used:-?}", "percent": "${disk_pct:-?}" },
  "uptime": "$uptime_str",
  "services": { $svcs_json },
  "open_ports": "$open_ports",
  "ssl_certificates": { $cert_json }
}
EOF
        return
    fi

    # ── Human-readable output ─────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}           VMBRO Server Report${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    echo -e "${BLUE}System${RESET}"
    echo -e "  Uptime  :  $uptime_str"
    echo -e "  CPU     :  $cpu_cores cores  |  Load avg: $load_avg"
    echo -e "  Memory  :  ${mem_used:-?}MB / ${mem_total:-?}MB  (${mem_pct:-?}%)"
    echo -e "  Disk /  :  ${disk_used:-?} / ${disk_total:-?}  (${disk_pct:-?})"
    echo ""

    echo -e "${BLUE}Services${RESET}"
    for svc in nginx caddy docker redis-server mongod; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${GREEN}●${RESET} $svc  (active)"
        elif systemctl list-units --all --quiet "$svc" 2>/dev/null | grep -q "$svc"; then
            echo -e "  ${RED}●${RESET} $svc  (inactive)"
        fi
    done
    echo ""

    echo -e "${BLUE}Open Ports${RESET}"
    local ports
    ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K\d+' | sort -un)
    if [[ -n "$ports" ]]; then
        echo "$ports" | while read -r p; do echo "  $p"; done
    else
        echo "  (none detected)"
    fi
    echo ""

    echo -e "${BLUE}SSL Certificates${RESET}"
    local found_cert=false
    for cert in /etc/letsencrypt/live/*/cert.pem; do
        if [[ -f "$cert" ]]; then
            found_cert=true
            local domain expiry days_left
            domain=$(echo "$cert" | grep -oP 'live/\K[^/]+')
            expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
            days_left=$(( ( $(date -d "$expiry" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))
            if [[ -n "$days_left" && "$days_left" -lt 14 ]]; then
                echo -e "  ${RED}●${RESET} $domain  —  expires in ${days_left} days"
            else
                echo -e "  ${GREEN}●${RESET} $domain  —  valid (${days_left:-?} days remaining)"
            fi
        fi
    done
    $found_cert || echo "  No certificates found"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}
