```
  ██╗   ██╗███╗   ███╗██████╗ ██████╗  ██████╗
  ██║   ██║████╗ ████║██╔══██╗██╔══██╗██╔═══██╗
  ██║   ██║██╔████╔██║██████╔╝██████╔╝██║   ██║
  ╚██╗ ██╔╝██║╚██╔╝██║██╔══██╗██╔══██╗██║   ██║
   ╚████╔╝ ██║ ╚═╝ ██║██████╔╝██║  ██║╚██████╔╝
    ╚═══╝  ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝
            Your VPS deployment copilot.
```

Fresh VPS to production in minutes.

`~54 KB total` · `0 required dependencies` · Ubuntu/Debian · root/sudo

```bash
git clone https://github.com/your-user/vmbro
cd vmbro && chmod +x vmbro.sh
sudo ./vmbro.sh init
```

---

## Commands

**Deploy**
```bash
vmbro init                 # pick what to deploy
vmbro deploy node          # Node.js + systemd + NGINX + SSL
vmbro deploy nextjs        # clone, build, and serve a Next.js app
vmbro deploy docker        # Dockerfile or docker-compose
```

**Diagnose**
```bash
vmbro doctor               # health check with scoring
vmbro report               # CPU, RAM, disk, SSL snapshot
vmbro report --json        # same but JSON
vmbro dashboard            # live terminal view, auto-refreshes
```

**Secure**
```bash
vmbro secure               # UFW, SSH hardening, fail2ban, auto-updates
```

**Backup**
```bash
vmbro backup create        # MongoDB, Redis, or Docker volumes
vmbro backup list
```

**Manage**
```bash
vmbro status  [service]
vmbro restart [service]
vmbro logs    [service]
vmbro reset   [service]    # destructive, use with care
vmbro config  view|edit
```

---

## What `vmbro doctor` looks like

```
VMBRO Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Docker running
  ✓ NGINX healthy
  ✓ SSL certificates OK
  ⚠ Swap not configured
  ✗ MongoDB listening on 0.0.0.0

Warnings
  -> No swap space configured
  -> Redis exposed on public interface

Critical
  -> MongoDB is exposed on 0.0.0.0 - bind to 127.0.0.1 in /etc/mongod.conf

Server Health Score: 74/100
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Structure

```
vmbro/
├── vmbro.sh              8.9 KB  entry point, command router
├── core/
│   ├── commands.sh       2.1 KB  restart, status, reset, logs
│   ├── config.sh         0.4 KB  JSON config load/write
│   └── utils.sh          0.8 KB  logging, prompts, root check

├── modules/
│   ├── deploy.sh         8.6 KB  node, nextjs, docker
│   ├── doctor.sh         9.5 KB  health checks
│   ├── secure.sh         6.0 KB  hardening
│   ├── report.sh         5.2 KB  snapshot
│   ├── dashboard.sh      3.5 KB  live terminal view
│   ├── backup.sh         3.8 KB  MongoDB, Redis, volumes
│   ├── nginx.sh          0.6 KB
│   ├── caddy.sh          0.8 KB
│   ├── node.sh           0.4 KB
│   ├── docker.sh         0.8 KB
│   ├── mongodb.sh        1.1 KB
│   └── redis.sh          0.7 KB
├── data/config.json
└── logs/vmbro.log
```

## Dependencies

None. vmbro auto-installs everything it needs.

`jq`, `git`, `nginx`, `certbot`, `ufw`, `fail2ban`, and `docker` are installed on demand as commands require them. `curl`, `openssl`, `ss`, and `systemctl` ship with Ubuntu/Debian.

MIT License
