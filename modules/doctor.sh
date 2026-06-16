#!/bin/bash

run_doctor() {
    local score=0
    local total=0
    local warnings=()
    local criticals=()

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}           VMBRO Health Report${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # Docker installed
    total=$((total + 1))
    if command -v docker &>/dev/null; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Docker installed"
    else
        echo -e "  ${YELLOW}⚠${RESET} Docker not installed"
        warnings+=("Docker is not installed")
    fi

    # Docker running
    total=$((total + 1))
    if systemctl is-active --quiet docker 2>/dev/null; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Docker running"
    else
        echo -e "  ${YELLOW}⚠${RESET} Docker not running"
        warnings+=("Docker service is not running")
    fi

    # NGINX healthy
    total=$((total + 1))
    if systemctl is-active --quiet nginx 2>/dev/null; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} NGINX healthy"
    elif command -v nginx &>/dev/null; then
        echo -e "  ${YELLOW}⚠${RESET} NGINX installed but not running"
        warnings+=("NGINX is installed but not running")
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} NGINX not installed (skipped)"
    fi

    # Caddy healthy
    total=$((total + 1))
    if systemctl is-active --quiet caddy 2>/dev/null; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Caddy healthy"
    elif command -v caddy &>/dev/null; then
        echo -e "  ${YELLOW}⚠${RESET} Caddy installed but not running"
        warnings+=("Caddy is installed but not running")
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Caddy not installed (skipped)"
    fi

    # Redis healthy
    total=$((total + 1))
    local redis_running=false
    systemctl is-active --quiet redis-server 2>/dev/null && redis_running=true
    docker ps --filter "name=redis" --filter "status=running" -q 2>/dev/null | grep -q . && redis_running=true

    if $redis_running; then
        if ss -tlnp 2>/dev/null | grep ':6379' | grep -qv '127.0.0.1'; then
            echo -e "  ${YELLOW}⚠${RESET} Redis running but exposed publicly"
            warnings+=("Redis is listening on a public interface — bind to 127.0.0.1")
        else
            score=$((score + 1))
            echo -e "  ${GREEN}✓${RESET} Redis healthy"
        fi
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Redis not installed (skipped)"
    fi

    # MongoDB healthy
    total=$((total + 1))
    local mongo_running=false
    systemctl is-active --quiet mongod 2>/dev/null && mongo_running=true
    docker ps --filter "name=mongo" --filter "status=running" -q 2>/dev/null | grep -q . && mongo_running=true

    if $mongo_running; then
        if ss -tlnp 2>/dev/null | grep ':27017' | grep -q '0\.0\.0\.0'; then
            echo -e "  ${RED}✗${RESET} MongoDB listening on 0.0.0.0"
            criticals+=("MongoDB is exposed on 0.0.0.0 — bind to 127.0.0.1 in /etc/mongod.conf")
        else
            score=$((score + 1))
            echo -e "  ${GREEN}✓${RESET} MongoDB healthy"
        fi
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} MongoDB not installed (skipped)"
    fi

    # Firewall / UFW
    total=$((total + 1))
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Firewall (UFW) enabled"
    else
        echo -e "  ${YELLOW}⚠${RESET} Firewall not enabled"
        warnings+=("UFW firewall is not active — run: vmbro secure")
    fi

    # Swap configured
    total=$((total + 1))
    if free | awk '/Swap:/ {exit ($2 > 0) ? 0 : 1}' 2>/dev/null; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Swap configured"
    else
        echo -e "  ${YELLOW}⚠${RESET} Swap not configured"
        warnings+=("No swap space configured — consider adding swap for stability")
    fi

    # Disk usage
    total=$((total + 1))
    local disk_usage
    disk_usage=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    if [[ -n "$disk_usage" ]]; then
        if [[ "$disk_usage" -gt 90 ]]; then
            echo -e "  ${RED}✗${RESET} Disk usage critical: ${disk_usage}%"
            criticals+=("Disk usage is at ${disk_usage}% — free up space immediately")
        elif [[ "$disk_usage" -gt 75 ]]; then
            echo -e "  ${YELLOW}⚠${RESET} Disk usage high: ${disk_usage}%"
            warnings+=("Disk usage is at ${disk_usage}%")
        else
            score=$((score + 1))
            echo -e "  ${GREEN}✓${RESET} Disk usage OK: ${disk_usage}%"
        fi
    fi

    # Memory pressure
    total=$((total + 1))
    local mem_used
    mem_used=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
    if [[ -n "$mem_used" ]]; then
        if [[ "$mem_used" -gt 90 ]]; then
            echo -e "  ${YELLOW}⚠${RESET} Memory usage high: ${mem_used}%"
            warnings+=("Memory usage is at ${mem_used}%")
        else
            score=$((score + 1))
            echo -e "  ${GREEN}✓${RESET} Memory usage OK: ${mem_used}%"
        fi
    fi

    # CPU load
    total=$((total + 1))
    local cpu_cores load_avg load_pct
    cpu_cores=$(nproc 2>/dev/null || echo 1)
    load_avg=$(awk '{printf "%.2f", $1}' /proc/loadavg 2>/dev/null || echo "0")
    load_pct=$(awk "BEGIN {printf \"%.0f\", $load_avg / $cpu_cores * 100}")
    if [[ "$load_pct" -gt 90 ]]; then
        echo -e "  ${YELLOW}⚠${RESET} CPU load high: $load_avg (${load_pct}%)"
        warnings+=("CPU load average is high: $load_avg")
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} CPU load OK: $load_avg"
    fi

    # SSL validity
    total=$((total + 1))
    local ssl_ok=true
    for cert in /etc/letsencrypt/live/*/cert.pem; do
        if [[ -f "$cert" ]]; then
            local expiry days_left
            expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
            days_left=$(( ( $(date -d "$expiry" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))
            if [[ -n "$days_left" && "$days_left" -lt 14 ]]; then
                ssl_ok=false
                echo -e "  ${YELLOW}⚠${RESET} SSL certificate expiring in ${days_left} days: $cert"
                warnings+=("SSL certificate expires in ${days_left} days")
            fi
        fi
    done
    if $ssl_ok; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} SSL certificates OK"
    fi

    # Open ports
    total=$((total + 1))
    if command -v ss &>/dev/null; then
        local open_ports
        open_ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K\d+' | sort -un | tr '\n' ' ')
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} Open ports: ${open_ports:-none}"
    fi

    # UFW rules
    total=$((total + 1))
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -qE "22|ssh"; then
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} SSH port allowed in firewall"
    else
        echo -e "  ${YELLOW}⚠${RESET} SSH may not be allowed in firewall"
        warnings+=("Verify SSH is allowed through firewall before enabling UFW")
    fi

    # Failed systemd services
    total=$((total + 1))
    local failed_count
    failed_count=$(systemctl --failed --no-legend 2>/dev/null | grep -c "failed" || echo 0)
    if [[ "$failed_count" -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${RESET} $failed_count failed systemd service(s)"
        warnings+=("$failed_count systemd service(s) are in failed state — run: systemctl --failed")
    else
        score=$((score + 1))
        echo -e "  ${GREEN}✓${RESET} No failed services"
    fi

    # Summary
    local health_score
    health_score=$(awk "BEGIN {printf \"%d\", $score / $total * 100}")

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warnings${RESET}"
        echo -e "${YELLOW}────────────────────────────────────────────────${RESET}"
        for w in "${warnings[@]}"; do
            echo -e "  ${YELLOW}→${RESET} $w"
        done
        echo ""
    fi

    if [[ ${#criticals[@]} -gt 0 ]]; then
        echo -e "${RED}Critical${RESET}"
        echo -e "${RED}────────────────────────────────────────────────${RESET}"
        for c in "${criticals[@]}"; do
            echo -e "  ${RED}→${RESET} $c"
        done
        echo ""
    fi

    local color
    if [[ "$health_score" -ge 80 ]]; then
        color="$GREEN"
    elif [[ "$health_score" -ge 60 ]]; then
        color="$YELLOW"
    else
        color="$RED"
    fi

    echo -e "${color}Server Health Score: ${health_score}/100${RESET}"
    echo -e "  Warnings:  ${#warnings[@]}"
    echo -e "  Critical:  ${#criticals[@]}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}
