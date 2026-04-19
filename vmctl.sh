#!/bin/bash

BASE_DIR="$(dirname "$0")"
CORE_DIR="$BASE_DIR/core"
MODULE_DIR="$BASE_DIR/modules"

source "$CORE_DIR/utils.sh"
source "$CORE_DIR/config.sh"
source "$CORE_DIR/commands.sh"

ensure_root
config_load

CMD="$1"
SUB="$2"

case "$CMD" in
    setup)
        bash "$BASE_DIR/setup-menu.sh"
        ;;

    restart)
        command_restart "$SUB"
        ;;

    status)
        command_status "$SUB"
        ;;

    reset)
        command_reset "$SUB"
        ;;

    config)
        case "$SUB" in
            view) command_config_view ;;
            edit) command_config_edit ;;
            *) echo "Usage: vmctl config [view|edit]";;
        esac
        ;;

    logs)
        command_logs "$SUB"
        ;;

    *)
        echo "Available commands:
  vmctl setup
  vmctl restart [service]
  vmctl status [service]
  vmctl reset [service]
  vmctl config view
  vmctl config edit
  vmctl logs [service]
"
        ;;
esac
