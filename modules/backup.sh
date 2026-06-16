#!/bin/bash

BACKUP_BASE="/var/backups/vmbro"

run_backup() {
    local sub="${1:-}"
    case "$sub" in
        create) _backup_create ;;
        list)   _backup_list   ;;
        *)
            echo "Usage: vmbro backup [create|list]"
            echo ""
            echo "  create   Create a new backup"
            echo "  list     List existing backups"
            ;;
    esac
}

_backup_create() {
    local backup_dir="$BACKUP_BASE/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    local choice
    choice=$(prompt_select "What would you like to back up?" \
        "MongoDB" \
        "Redis" \
        "Docker Volumes" \
        "All" \
        "Cancel")

    case "$choice" in
        "MongoDB")        _backup_mongodb "$backup_dir" ;;
        "Redis")          _backup_redis   "$backup_dir" ;;
        "Docker Volumes") _backup_docker_volumes "$backup_dir" ;;
        "All")
            _backup_mongodb       "$backup_dir"
            _backup_redis         "$backup_dir"
            _backup_docker_volumes "$backup_dir"
            ;;
        *) return ;;
    esac

    echo ""
    log_info "Backup saved to $backup_dir"
    ls -lh "$backup_dir" 2>/dev/null || true
}

_backup_list() {
    if [[ ! -d "$BACKUP_BASE" ]]; then
        log_warn "No backups found in $BACKUP_BASE"
        return
    fi

    echo ""
    echo -e "${BLUE}Available backups:${RESET}"
    echo ""
    while IFS= read -r dir; do
        local size
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo -e "  ${GREEN}●${RESET} $(basename "$dir")  (${size:-?})"
    done < <(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d | sort -r)
    echo ""
}

_backup_mongodb() {
    local dest="$1"

    if ! command -v mongodump &>/dev/null && ! systemctl is-active --quiet mongod 2>/dev/null; then
        log_warn "MongoDB not running — skipping MongoDB backup."
        return
    fi

    log_info "Backing up MongoDB..."
    if run_safe "mongodump --out $dest/mongodb"; then
        log_info "MongoDB backup complete: $dest/mongodb"
    fi
}

_backup_redis() {
    local dest="$1"

    # Try standard dump locations
    local redis_dump=""
    for path in /var/lib/redis/dump.rdb /data/dump.rdb; do
        [[ -f "$path" ]] && redis_dump="$path" && break
    done

    if [[ -z "$redis_dump" ]]; then
        # Try to find it via redis-cli CONFIG
        if command -v redis-cli &>/dev/null; then
            local rdb_path
            rdb_path=$(redis-cli CONFIG GET dir 2>/dev/null | awk 'NR==2')
            local rdb_file
            rdb_file=$(redis-cli CONFIG GET dbfilename 2>/dev/null | awk 'NR==2')
            [[ -n "$rdb_path" && -n "$rdb_file" && -f "$rdb_path/$rdb_file" ]] \
                && redis_dump="$rdb_path/$rdb_file"
        fi
    fi

    if [[ -z "$redis_dump" ]]; then
        log_warn "Redis dump file not found — skipping Redis backup."
        return
    fi

    log_info "Backing up Redis from $redis_dump..."
    cp "$redis_dump" "$dest/redis-dump.rdb"
    log_info "Redis backup complete: $dest/redis-dump.rdb"
}

_backup_docker_volumes() {
    local dest="$1"

    if ! command -v docker &>/dev/null; then
        log_warn "Docker not installed — skipping volume backup."
        return
    fi

    local volumes
    volumes=$(docker volume ls -q 2>/dev/null)
    if [[ -z "$volumes" ]]; then
        log_warn "No Docker volumes found."
        return
    fi

    log_info "Backing up Docker volumes..."
    mkdir -p "$dest/docker-volumes"

    while read -r vol; do
        log_info "  Backing up volume: $vol"
        docker run --rm \
            -v "$vol":/data \
            -v "$dest/docker-volumes":/backup \
            alpine sh -c "tar czf /backup/$vol.tar.gz -C /data . 2>/dev/null" \
            && log_info "    Saved: $vol.tar.gz" \
            || log_warn "    Failed to back up volume: $vol"
    done <<< "$volumes"

    log_info "Docker volume backup complete."
}
