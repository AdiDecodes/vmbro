# VMBRO

`vmbro` is a modular, Bash-based command-line utility designed for automated provisioning and service management on Linux Virtual Machines (Ubuntu/Debian based). It provides a streamlined interface for installing, configuring, and monitoring essential web infrastructure components.

## Features

- 🛠 **Interactive Setup Menu:** Clean, prompt-based GUI for installing dependencies.
- 📦 **Modular Architecture:** Drop-in scripts for expanding supported software (e.g., Docker, NGINX, Redis).
- 🔄 **Service Management:** unified commands for restarting, resetting, reading logs, and checking service status.
- ⚙️ **JSON Configuration:** Maintains application state via `jq` formatted configurations.
- 📜 **Safe Executions & Logging:** Built-in safeguards that log all script operations to a central log file for debugging.

## Supported Modules

Currently, `vmbro` comes with out-of-the-box installation and configuration support for:
- Web Servers: **NGINX**, **Caddy**
- Runtime Environments: **Node.js**
- Containerization: **Docker**
- Databases & Caching: **MongoDB**, **Redis**

## Prerequisites

- Base OS: **Ubuntu / Debian** (Uses `apt` package manager and `systemctl`).
- **Root privileges** are required (run via `sudo`).
- Dependencies: **jq** (required for reading and writing `config.json`).

## Project Structure

```text
vmbro/
├── vmbro.sh             # Main executable entry point
├── core/                # Core engine components
│   ├── commands.sh      # Service command implementations
│   ├── config.sh        # JSON configurations loader/writer
│   ├── setup-menu.sh    # Interactive selection menus
│   └── utils.sh         # Helper functions for logging, prompts, etc.
├── modules/             # Service deployment scripts
│   ├── caddy.sh
│   ├── docker.sh
│   ├── mongodb.sh
│   ├── nginx.sh
│   ├── node.sh
│   └── redis.sh
├── data/
│   └── config.json      # Dynamic metadata state
└── logs/
    └── vmbro.log        # Unified action records
```

## Usage

Make sure the main script is executable before using it:

```bash
chmod +x vmbro.sh
```

### Setup Components

To open the interactive menu and install components:

```bash
sudo ./vmbro.sh setup
```

### Commands Line Reference

| Command | Description |
|---|---|
| `sudo ./vmbro.sh setup` | Opens the interactive interactive setup menu. |
| `sudo ./vmbro.sh restart <service$|all>` | Restarts a specific service (`nginx`, `docker`, `redis`, `mongo`, or `all`). |
| `sudo ./vmbro.sh status [service]` | Displays systemctl status. Omit the service name for an overview of all supported services. |
| `sudo ./vmbro.sh reset <service$|all>` | ⚠️ **DANGEROUS**: Wipes data or configurations and resets the specified service layer. |
| `sudo ./vmbro.sh config view` | Prints the current parsed `config.json` state. |
| `sudo ./vmbro.sh config edit` | Opens the configuration file in `nano`. |
| `sudo ./vmbro.sh logs <service>` | Shows the last 50 journalctl logs for the given service. |

## License

MIT License (or your desired respective repository license).
