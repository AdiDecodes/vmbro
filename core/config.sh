#!/bin/bash

CONFIG_FILE="$BASE_DIR/data/config.json"

config_load() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '{"services":{}}' > "$CONFIG_FILE"
    fi
}

config_view() {
    cat "$CONFIG_FILE" | jq .
}

config_set() {
    # Usage: config_set services.nginx.enabled true
    local key="$1"
    local val="$2"
    jq ".$key = $val" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}
