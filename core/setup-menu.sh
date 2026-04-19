#!/bin/bash

source "$MODULE_DIR/node.sh"
source "$MODULE_DIR/nginx.sh"
source "$MODULE_DIR/docker.sh"
source "$MODULE_DIR/redis.sh"
source "$MODULE_DIR/mongodb.sh"

while true; do
    choice=$(prompt_select "Choose component to install:" \
        "Node.js" "Nginx" "Caddy" "Docker" "Redis" "MongoDB" "Back")

    case "$choice" in
        "Node.js") install_node ;;
        "Nginx") install_nginx ;;
        "Caddy") install_caddy ;;
        "Docker") install_docker ;;
        "Redis") install_redis_flow ;;
        "MongoDB") install_mongo_flow ;;
        "Back") exit 0 ;;
    esac
done
