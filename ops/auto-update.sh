#!/usr/bin/env bash
# Installed once by the server administrator. Pulls only the runtime files.
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/qingxu-web}"
REPOSITORY="${REPOSITORY:-https://github.com/wei725696-crypto/QINGXU.git}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:18080/healthz}"
FORCE="${1:-}"
FILES=(Dockerfile nginx.conf index.html app.js style.css)

log() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }
for dependency in git docker curl flock tar; do
    command -v "$dependency" >/dev/null || { log "Missing dependency: $dependency"; exit 1; }
done
[[ "$APP_DIR" = /* && -d "$APP_DIR" ]] || { log "APP_DIR must be an existing absolute directory"; exit 1; }
cd "$APP_DIR"
APP_DIR="$(pwd -P)"
STATE="$APP_DIR/.auto-deploy"
mkdir -p "$STATE"
exec 9>"$STATE/update.lock"
flock -n 9 || exit 0

if command -v docker-compose >/dev/null; then
    COMPOSE=(docker-compose)
else
    docker compose version >/dev/null
    COMPOSE=(docker compose)
fi
compose() { "${COMPOSE[@]}" -p qingxu-web -f "$APP_DIR/docker-compose.yml" "$@"; }
compose config --quiet
container_id="$(compose ps -q web)"
[[ -n "$container_id" ]] || { log "Existing web container not found; verify the project name"; exit 1; }
old_image_id="$(docker inspect --format '{{.Image}}' "$container_id")"
image_name="$(docker inspect --format '{{.Config.Image}}' "$container_id")"

cache="$STATE/repository.git"
if [[ ! -e "$cache" ]]; then git init --bare "$cache"; fi
export GIT_TERMINAL_PROMPT=0
git -c credential.helper= -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=30 \
    --git-dir="$cache" fetch --depth=1 --no-tags "$REPOSITORY" "refs/heads/$DEPLOY_BRANCH"
target="$(git --git-dir="$cache" rev-parse FETCH_HEAD)"
if [[ "$FORCE" != "--force" ]]; then
    for marker in last-success failed-commit; do
        if [[ -f "$STATE/$marker" && "$(cat "$STATE/$marker")" = "$target" ]]; then
            log "$marker already records $target; no deployment"
            exit 0
        fi
    done
fi

run="$STATE/runs/$(date +%Y%m%dT%H%M%S)-$$"
mkdir -p "$run/candidate" "$run/previous"
git --git-dir="$cache" archive --format=tar -o "$run/source.tar" "$target" "${FILES[@]}"
tar -xf "$run/source.tar" -C "$run/candidate"
for file in "${FILES[@]}"; do
    [[ -f "$run/candidate/$file" && ! -L "$run/candidate/$file" ]] || exit 1
    [[ -f "$APP_DIR/$file" && ! -L "$APP_DIR/$file" ]] || {
        log "Expected existing regular file: $file"; exit 1;
    }
    cp -p "$APP_DIR/$file" "$run/previous/$file"
done
printf '%s\n' "$old_image_id" >"$run/previous-image"
printf '%s\n' "$image_name" >"$run/image-name"
printf '%s\n' "$target" >"$run/target-commit"

healthy() {
    local expected_image="$1" current_container current_image body
    for attempt in {1..20}; do
        current_container="$(compose ps -q web)" || current_container=""
        current_image=""
        if [[ -n "$current_container" ]]; then
            current_image="$(docker inspect --format '{{.Image}}' "$current_container" 2>/dev/null)" || current_image=""
        fi
        body="$(curl --fail --silent --show-error --max-time 3 "$HEALTH_URL" 2>/dev/null)" || body=""
        if [[ "$current_image" = "$expected_image" && "$body" = "ok" ]]; then return 0; fi
        sleep 2
    done
    return 1
}

applying=0
finish() {
    result=$?
    trap - EXIT
    if [[ "$result" != 0 && "$applying" = 1 ]]; then
        set +e
        log "Deployment failed; restoring files and the previous Docker image"
        printf '%s\n' "$target" >"$STATE/failed-commit"
        for file in "${FILES[@]}"; do cp -p "$run/previous/$file" "$APP_DIR/$file"; done
        docker image tag "$old_image_id" "$image_name"
        compose up -d --no-deps --no-build web
        if healthy "$old_image_id"; then
            log "Rollback health check passed"
        else
            log "ROLLBACK NEEDS MANUAL ATTENTION; backup directory: $run"
        fi
    fi
    exit "$result"
}
trap finish EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

applying=1
for file in "${FILES[@]}"; do cp "$run/candidate/$file" "$APP_DIR/$file"; done
log "Building commit $target"
compose build web
new_image_id="$(docker image inspect --format '{{.Id}}' "$image_name")"
compose up -d --no-deps --no-build web
healthy "$new_image_id"
printf '%s\n' "$target" >"$STATE/last-success.tmp"
mv "$STATE/last-success.tmp" "$STATE/last-success"
applying=0
log "Deployed $target; HTTP and container image checks passed"
