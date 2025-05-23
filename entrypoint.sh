#!/bin/bash
set -e
SETUP_DIR="../setup"
WORK_DIR="."
TMUX_SESSION="purpur"
BACKUP_DIR="/opt/backup"
WORLDS=("world" "world_nether" "world_the_end")

JAR_DIRECTORY="/opt/minecraft"
JAR_FILE_PREFIX="purpur-"
JAR_FILE_SUFFIX=".jar"


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
    tmux new-session -d -s $TMUX_SESSION
    tmux send-keys -t $TMUX_SESSION "java -jar ${JAR_DIRECTORY}/${JAR_FILE_PREFIX}${VERSION}${JAR_FILE_SUFFIX} --nogui" C-m
    sleep 20
    stop_command
}
# start
start_command() {
    log "Starting the application..."
    update_eula
    copy_file $SETUP_DIR $WORK_DIR 'Setup: '
    tmux new-session -d -s $TMUX_SESSION
    tmux send-keys -t $TMUX_SESSION 'JAVA_MEMORY_MAX=$JAVA_MEMORY_MAX JAVA_MEMORY_MIN=$JAVA_MEMORY_MIN /run.sh' C-m

    while check_server_status; do
      sleep 1
    done

    log "Application started in tmux session"
}

#stop
stop_command() {
    log "Stopping the application..."
    tmux send-keys -t $TMUX_SESSION "stop" C-m
    sleep 10
    log "Current directory: $(pwd)"
    copy_file $WORK_DIR $SETUP_DIR 'Cleanup: '
    log "Copy attempts completed."

    tmux has-session -t $TMUX_SESSION 2>/dev/null && tmux kill-session -t $TMUX_SESSION

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
        log "Tmux session ended. Exiting..."
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
