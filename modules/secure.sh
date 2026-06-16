#!/bin/bash

run_secure() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}           VMBRO Security Hardening${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    local score=0
    local total=6

    # ── Step 1: Firewall (UFW) ──────────────────────────────────────────────
    echo -e "${BLUE}[1/$total]${RESET} Configuring firewall (UFW)..."

    run_safe "apt-get install -y ufw"
    ufw --force reset >/dev/null 2>&1
    run_safe "ufw default deny incoming"
    run_safe "ufw default allow outgoing"
    run_safe "ufw allow 22/tcp"
    run_safe "ufw allow 80/tcp"
    run_safe "ufw allow 443/tcp"
    run_safe "ufw --force enable"

    score=$((score + 1))
    log_info "Firewall configured. (SSH, HTTP, HTTPS allowed)"

    # ── Step 2: SSH hardening ──────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}[2/$total]${RESET} Hardening SSH..."

    local sshd_conf="/etc/ssh/sshd_config"
    if [[ -f "$sshd_conf" ]]; then
        # Disable root login
        if grep -qE "^#?PermitRootLogin" "$sshd_conf"; then
            sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$sshd_conf"
        else
            echo "PermitRootLogin no" >> "$sshd_conf"
        fi

        # Reduce max auth tries
        if grep -qE "^#?MaxAuthTries" "$sshd_conf"; then
            sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$sshd_conf"
        else
            echo "MaxAuthTries 3" >> "$sshd_conf"
        fi

        if prompt_yes_no "  Disable SSH password authentication? (ensure you have key-based access first)"; then
            if grep -qE "^#?PasswordAuthentication" "$sshd_conf"; then
                sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_conf"
            else
                echo "PasswordAuthentication no" >> "$sshd_conf"
            fi
            log_info "Password authentication disabled."
        fi

        run_safe "systemctl reload ssh || systemctl reload sshd"
    else
        log_warn "sshd_config not found — skipping SSH hardening."
    fi

    score=$((score + 1))
    log_info "SSH hardened."

    # ── Step 3: fail2ban ──────────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}[3/$total]${RESET} Installing fail2ban..."

    run_safe "apt-get install -y fail2ban"
    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

    run_safe "systemctl enable fail2ban --now"
    score=$((score + 1))
    log_info "fail2ban configured (5 retries → 1 hour ban)."

    # ── Step 4: Automatic security updates ───────────────────────────────
    echo ""
    echo -e "${BLUE}[4/$total]${RESET} Enabling automatic security updates..."

    run_safe "apt-get install -y unattended-upgrades"
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

    cat > /etc/apt/apt.conf.d/50unattended-upgrades-vmbro <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    run_safe "dpkg-reconfigure --frontend=noninteractive unattended-upgrades"
    score=$((score + 1))
    log_info "Automatic security updates enabled."

    # ── Step 5: Kernel hardening ──────────────────────────────────────────
    echo ""
    echo -e "${BLUE}[5/$total]${RESET} Applying kernel hardening via sysctl..."

    cat > /etc/sysctl.d/99-vmbro-hardening.conf <<'EOF'
# Prevent IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martian packets
net.ipv4.conf.all.log_martians = 1

# Disable IP forwarding (enable only if using Docker with bridge networking)
net.ipv4.ip_forward = 0

# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1
EOF

    run_safe "sysctl --system"
    score=$((score + 1))
    log_info "Kernel hardening applied."

    # ── Step 6: Shared memory ─────────────────────────────────────────────
    echo ""
    echo -e "${BLUE}[6/$total]${RESET} Securing shared memory..."

    if ! grep -q "tmpfs.*noexec.*nosuid" /etc/fstab 2>/dev/null; then
        echo "tmpfs /run/shm tmpfs ro,noexec,nosuid 0 0" >> /etc/fstab
        log_info "Shared memory secured."
    else
        log_info "Shared memory already secured."
    fi

    score=$((score + 1))

    # ── Summary ───────────────────────────────────────────────────────────
    local sec_score
    sec_score=$(awk "BEGIN {printf \"%d\", $score / $total * 100}")

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}Security Score: ${sec_score}/100${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}
