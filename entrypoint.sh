#!/bin/bash
set -e
SETUP_DIR="../setup"
WORK_DIR="."
TMUX_SESSION="purpur"
BACKUP_DIR="/opt/backup"
# Directories under the server directory to back up. Missing ones are skipped.
BACKUP_TARGETS=("world" "plugins")

JAR_DIRECTORY="/opt/minecraft"
# Symlink to the jar in use (purpur-<version>-<build>.jar). run.sh starts it.
CURRENT_JAR="$JAR_DIRECTORY/purpur.jar"
PURPUR_API="https://api.purpurmc.org/v2/purpur"
EXIT_CODE_FILE="/tmp/purpur_exit_code"
# Keep this below stop_grace_period in docker-compose.yml.
STOP_TIMEOUT=120
SAVE_TIMEOUT=60


log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> /var/log/entrypoint.log
    echo "$message" >&2
    echo $1
}

update_eula() {
  if [ "$EULA" = "true" ]; then
    echo "Accepting Minecraft EULA..."
    echo "eula=true" > eula.txt
  else
    echo "Not accepting Minecraft EULA. Server will not start."
    echo "eula=false" > eula.txt
    exit 1
  fi
}

# init
init_command() {
    log "Initializing the application..."
    set_stop_trap
    update_eula
    ensure_server_jar || exit 1
    tmux new-session -d -s $TMUX_SESSION "java -jar $CURRENT_JAR --nogui"
    sleep 20
    stop_command
}
# start
start_command() {
    log "Starting the application..."
    set_stop_trap
    update_eula
    copy_file $SETUP_DIR $WORK_DIR 'Setup: '

    ensure_server_jar || exit 1

    # Run the server as the session's own process, so the session (and this
    # container) ends when Java exits instead of leaving an idle shell behind.
    rm -f $EXIT_CODE_FILE
    tmux new-session -d -s $TMUX_SESSION "/run.sh; echo \$? > $EXIT_CODE_FILE"
    log "Server started in tmux session"

    while check_server_status; do
      sleep 1
    done

    local exit_code
    exit_code=$(cat $EXIT_CODE_FILE 2>/dev/null || echo unknown)
    log "Server process exited (exit code: $exit_code)"
    copy_file $WORK_DIR $SETUP_DIR 'Cleanup: '
    exit 1
}

#stop
stop_command() {
    log "Stopping the application..."
    if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
      tmux send-keys -t $TMUX_SESSION "stop" C-m

      # Wait for Java to finish saving and exit, instead of a fixed sleep.
      local elapsed=0
      while tmux has-session -t $TMUX_SESSION 2>/dev/null && [ $elapsed -lt $STOP_TIMEOUT ]; do
        sleep 1
        elapsed=$((elapsed + 1))
      done

      if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
        log "Server did not stop within ${STOP_TIMEOUT}s. Killing the session."
        tmux kill-session -t $TMUX_SESSION
      else
        log "Server stopped in ${elapsed}s"
      fi
    fi

    copy_file $WORK_DIR $SETUP_DIR 'Cleanup: '
    log "Stop command completed"
}

#backup
backup_command () {
    log "Starting backup process..."
    mkdir -p $BACKUP_DIR
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/worlds_backup_$TIMESTAMP.tar.zst"

    local server_running=false
    if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
      server_running=true
      # Make sure auto-save is turned back on even if the backup is interrupted.
      trap 'resume_saving; exit 1' SIGTERM SIGINT
      log "Disabling auto-save and flushing the world to disk..."
      tmux send-keys -t $TMUX_SESSION 'save-off' C-m
      if ! flush_and_wait; then
        resume_saving
        return 1
      fi
    fi

    local targets=()
    for target in "${BACKUP_TARGETS[@]}"; do
      if [ -e "$WORK_DIR/$target" ]; then
        targets+=("$target")
      else
        log "Skipping missing backup target: $target"
      fi
    done

    log "Creating backup archive (${targets[*]})..."
    local result=0
    # zstd with all cores (-T0) is much faster than single-threaded gzip.
    tar -I 'zstd -T0' -cf $BACKUP_FILE -C $WORK_DIR "${targets[@]}" || result=$?

    if [ "$server_running" = true ]; then
      resume_saving
      trap - SIGTERM SIGINT
    fi

    if [ $result -ne 0 ]; then
      log "Failed to create backup"
      return 1
    fi
    log "Backup created successfully: $BACKUP_FILE"

    log "Cleaning up old backups..."
    # Also count backups made as .tar.gz before switching to zstd.
    ls -t $BACKUP_DIR/worlds_backup_*.tar.zst $BACKUP_DIR/worlds_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm

    log "Backup process completed"
}

# Run `save-all flush` and wait until the server reports that it has finished.
flush_and_wait() {
    local log_file="$WORK_DIR/logs/latest.log"
    local offset
    offset=$(wc -l < "$log_file")
    tmux send-keys -t $TMUX_SESSION 'save-all flush' C-m

    local elapsed=0
    while [ $elapsed -lt $SAVE_TIMEOUT ]; do
      if tail -n +$((offset + 1)) "$log_file" | grep -q 'Saved the game'; then
        log "World saved in ${elapsed}s"
        return 0
      fi
      sleep 1
      elapsed=$((elapsed + 1))
    done
    log "Server did not finish saving within ${SAVE_TIMEOUT}s. Aborting backup."
    return 1
}

resume_saving() {
    log "Re-enabling auto-save..."
    tmux send-keys -t $TMUX_SESSION 'save-on' C-m
}

# update
update_command () {
    if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
      log "The server is running. Stop it first (make update stops it for you)."
      return 1
    fi
    ensure_server_jar || return 1

    local current version build latest
    current=$(current_version_build)
    version=${current% *}
    build=${current#* }
    latest=$(api_get "/$version" | jq -r '.builds.latest // empty')
    if [ -z "$latest" ]; then
      log "Could not get the latest build of $version from the Purpur API"
      return 1
    fi

    if [ "$build" = "$latest" ]; then
      log "Already up to date: $version build $build"
      return 0
    fi

    log "Updating: $version build $build -> $latest"
    backup_command || { log "Backup failed. Update aborted."; return 1; }
    install_build "$version" "$latest" || return 1
    log "Updated: $version build $build -> $latest"
}

# Retry on any error: connections to the API are occasionally reset.
CURL_RETRY=(--retry 3 --retry-delay 2 --retry-all-errors)

api_get() {
    curl -fsSL "${CURL_RETRY[@]}" "$PURPUR_API$1"
}

# Print "<version> <build>" of the jar in use. The build is "unknown" for a jar
# installed before builds were tracked (purpur-<version>.jar).
current_version_build() {
    local name rest
    name=$(basename "$(readlink "$CURRENT_JAR")" .jar)
    rest=${name#purpur-}
    if [[ "${rest##*-}" =~ ^[0-9]+$ ]] && [ "$rest" != "${rest##*-}" ]; then
      echo "${rest%-*} ${rest##*-}"
    else
      echo "$rest unknown"
    fi
}

# Make sure purpur.jar points to a server jar. On the first run after this
# change, reuse purpur-$VERSION.jar; on a fresh volume, install the latest build
# of $VERSION.
ensure_server_jar() {
    [ -e "$CURRENT_JAR" ] && return 0

    local legacy="$JAR_DIRECTORY/purpur-$VERSION.jar"
    if [ -f "$legacy" ]; then
      ln -sfn "$(basename "$legacy")" "$CURRENT_JAR"
      log "Using existing $(basename "$legacy") as the server jar"
      return 0
    fi

    if [ -z "$VERSION" ]; then
      log "No server jar installed and VERSION is not set in .env"
      return 1
    fi
    local build
    build=$(api_get "/$VERSION" | jq -r '.builds.latest // empty')
    if [ -z "$build" ]; then
      log "Could not get version $VERSION from the Purpur API (not found or network error)"
      return 1
    fi
    log "Installing Purpur $VERSION build $build"
    install_build "$VERSION" "$build"
}

# Download (if needed) and verify purpur-<version>-<build>.jar, check that it
# runs on this image's Java, then point purpur.jar to it.
install_build() {
    local version=$1 build=$2
    local name="purpur-$version-$build.jar"
    local file="$JAR_DIRECTORY/$name"
    local downloaded=false

    if [ ! -f "$file" ]; then
      local md5 tmp actual
      md5=$(api_get "/$version/$build" | jq -r '.md5 // empty')
      if [ -z "$md5" ]; then
        log "Could not get build $build of $version from the Purpur API (not found or network error)"
        return 1
      fi
      tmp=$(mktemp "$JAR_DIRECTORY/.download.XXXXXX")
      log "Downloading $name..."
      local status=0
      curl -fsSL "${CURL_RETRY[@]}" -o "$tmp" "$PURPUR_API/$version/$build/download" || status=$?
      if [ $status -ne 0 ]; then
        log "Download failed (curl exit code: $status)"
        rm -f "$tmp"
        return 1
      fi
      actual=$(md5sum "$tmp" | cut -d' ' -f1)
      if [ "$actual" != "$md5" ]; then
        log "Checksum mismatch (expected $md5, got $actual)"
        rm -f "$tmp"
        return 1
      fi
      chmod 644 "$tmp"
      mv "$tmp" "$file"
      downloaded=true
    fi

    if ! check_java_compat "$file"; then
      [ "$downloaded" = true ] && rm -f "$file"
      return 1
    fi

    local previous
    previous=$(basename "$(readlink "$CURRENT_JAR" 2>/dev/null)" 2>/dev/null || true)
    ln -sfn "$name" "$CURRENT_JAR"
    prune_jars "$name" "$previous"
}

# The jar only contains a patch for the server, so apply it (patch only, the
# server is not started) and read the class file version of the patched server.
check_java_compat() {
    local file=$1
    log "Checking Java compatibility..."
    if ! (cd "$JAR_DIRECTORY" && java -Dpaperclip.patchonly=true -jar "$file" > /dev/null); then
      log "Failed to prepare $(basename "$file")"
      return 1
    fi

    local server_jar major required available
    server_jar="$JAR_DIRECTORY/versions/$(unzip -p "$file" META-INF/versions.list | awk '{print $3}')"
    major=$(unzip -p "$server_jar" net/minecraft/server/Main.class 2>/dev/null | od -An -j6 -N2 -tu1 | awk 'NF == 2 {print $1 * 256 + $2}')
    if [ -z "$major" ]; then
      log "Could not read the Java version required by $(basename "$file")"
      return 1
    fi
    required=$((major - 44))
    available=$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}')
    if [ "$required" -gt "$available" ]; then
      log "$(basename "$file") requires Java $required, but this image has Java $available. Update the Dockerfile first."
      return 1
    fi
    log "Java $required required, Java $available available: OK"
}

# Keep the jar in use and the previous one (for rolling back), remove the rest.
prune_jars() {
    local keep1=$1 keep2=$2 f
    for f in "$JAR_DIRECTORY"/purpur-*.jar; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in
        "$keep1"|"$keep2") ;;
        *) log "Removing old jar: $(basename "$f")"; rm -f "$f" ;;
      esac
    done
}

copy_file() {
    local src=$1
    local dest=$2
    local log_prefix=$3

    # -u: only overwrite when the source is newer, so edits made in setup/
    # while the server is running are not overwritten on stop.
    # -p: keep timestamps so the comparison stays meaningful.
    cp -pu $src/*.json $dest/ 2>/dev/null || log "$log_prefix Failed to copy JSON files"
    cp -pu $src/*.yml $dest/ 2>/dev/null || log "$log_prefix Failed to copy YAML files"
    cp -rpu $src/config $dest/ 2>/dev/null || log "$log_prefix Failed to copy config directory"
    cp -pu $src/server.properties $dest/ 2>/dev/null || log "$log_prefix Failed to copy server.properties"
    mv $src/ops.txt $dest/ 2>/dev/null || log "$log_prefix Failed to move ops.txt"

    log "$log_prefix Copy attempts completed."
    ls -l $dest/ >> /var/log/entrypoint.log
}

check_server_status() {
    if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
        log "Tmux session ended."
        return 1
    fi
    return 0
}

# Only for commands that own the server process (init/start). Other commands
# such as `backup` run via `docker compose exec` must not stop the server
# when they receive Ctrl+C.
set_stop_trap() {
    trap 'log "Received SIGTERM/SIGINT"; stop_command; log "Exiting"; exit 0' SIGTERM SIGINT
}

case "$1" in
  init)
    init_command
    ;;
  start)
    start_command
    ;;
  stop)
    stop_command
    ;;
  backup)
    backup_command
    ;;
  update)
    update_command
    ;;
  *)
    exec "$@"
    ;;
esac

log "Entrypoint script exiting"
