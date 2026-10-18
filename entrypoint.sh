#!/bin/bash
set -e
SETUP_DIR="../setup"
WORK_DIR="."
TMUX_SESSION="purpur"
BACKUP_DIR="/opt/backup"
WORLDS=("world")

JAR_DIRECTORY="/opt/minecraft"
JAR_FILE_PREFIX="purpur-"
JAR_FILE_SUFFIX=".jar"
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
    sed -i s/eula=.*/eula=true/ eula.txt
  else
    echo "Not accepting Minecraft EULA. Server will not start."
    sed -i s/eula=.*/eula=false/ eula.txt
    exit 1
  fi
}

# init
init_command() {
    log "Initializing the application..."
    set_stop_trap
    update_eula
    tmux new-session -d -s $TMUX_SESSION "java -jar ${JAR_DIRECTORY}/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX} --nogui"
    sleep 20
    stop_command
}
# start
start_command() {
    log "Starting the application..."
    set_stop_trap
    update_eula
    copy_file $SETUP_DIR $WORK_DIR 'Setup: '

    local jar="${JAR_DIRECTORY}/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX}"
    if [ ! -f "$jar" ]; then
      log "Server jar not found: $jar (run 'make update' after changing VERSION)"
      exit 1
    fi

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

    log "Creating backup archive..."
    local result=0
    # zstd with all cores (-T0) is much faster than single-threaded gzip.
    tar -I 'zstd -T0' -cf $BACKUP_FILE -C $WORK_DIR ${WORLDS[@]} || result=$?

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
  if [ -f "${JAR_DIRECTORY}/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX}" ]; then
    log "Version $VERSION is already installed. No update needed."
  else
    log "Version $VERSION is not installed. Installing now."

    log "Installing new version: ${VERSION}"
    curl -L -o "$JAR_DIRECTORY/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX}" "https://api.purpurmc.org/v2/purpur/${VERSION}/latest/download"
    log "Version ${VERSION} installed successfully."
  fi
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
