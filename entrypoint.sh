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
    update_eula
    tmux new-session -d -s $TMUX_SESSION "java -jar ${JAR_DIRECTORY}/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX} --nogui"
    sleep 20
    stop_command
}
# start
start_command() {
    log "Starting the application..."
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
    BACKUP_FILE="$BACKUP_DIR/worlds_backup_$TIMESTAMP.tar.gz"

    if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
      log "Sending save-all command to the server..."
      tmux send-keys -t $TMUX_SESSION 'save-all' C-m
      sleep 10
    fi

    log "Creating backup archive..."
    if tar -czf $BACKUP_FILE -C $WORK_DIR ${WORLDS[@]}; then
      log "Backup created successfully: $BACKUP_FILE"
    else
      log "Failed to create backup"
      return 1
    fi

    log "Cleaning up old backups..."
    ls -t $BACKUP_DIR/worlds_backup_*.tar.gz | tail -n +6 | xargs -r rm

    log "Backup process completed"
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
    
    cp $src/*.json $dest/ 2>/dev/null || log "$log_prefix Failed to copy JSON files"
    cp $src/*.yml $dest/ 2>/dev/null || log "$log_prefix Failed to copy YAML files"
    cp -r $src/config $dest/ 2>/dev/null || log "$log_prefix Failed to copy config directory"
    cp $src/server.properties $dest/ 2>/dev/null || log "$log_prefix Failed to copy server.properties"
    mv $src/ops.txt $dest/ 2>/dev/null || log "$log_prefix Failed to move server.properties"

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

trap 'log "Received SIGTERM/SIGINT"; stop_command; log "Exiting"; exit 0' SIGTERM SIGINT

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
