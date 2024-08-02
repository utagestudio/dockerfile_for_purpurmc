#!/bin/bash
set -e
SETUP_DIR="../setup"
WORK_DIR="."
TMUX_SESSION="purpur"

log() {
     local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> /var/log/entrypoint.log
    echo "$message" >&2
    echo $1
}

# start
start_command() {
    log "Starting the application..."
    copy_file $SETUP_DIR $WORK_DIR 'Setup: '
    tmux_command new-session -d -s $TMUX_SESSION
    tmux_command send-keys -t $TMUX_SESSION 'JAVA_MEMORY_MAX=$JAVA_MEMORY_MAX JAVA_MEMORY_MIN=$JAVA_MEMORY_MIN /run.sh' C-m

    while check_server_status; do
      sleep 1
    done

    log "Application started in tmux session"
}

#stop
stop_command() {
    log "Stopping the application..."
    tmux_command send-keys -t $TMUX_SESSION "stop" C-m
    sleep 10
    log "Current directory: $(pwd)"
    copy_file $WORK_DIR $SETUP_DIR 'Cleanup: '
    log "Copy attempts completed."

    tmux_command has-session -t $TMUX_SESSION 2>/dev/null && tmux_command kill-session -t $TMUX_SESSION

    log "Stop command completed"
}

copy_file() {
    local src=$1
    local dest=$2
    local log_prefix=$3
    
    cp $src/*.json $dest/ 2>/dev/null || log "$log_prefix Failed to copy JSON files"
    cp $src/*.yml $dest/ 2>/dev/null || log "$log_prefix Failed to copy YAML files"
    cp -r $src/config $dest/ 2>/dev/null || log "$log_prefix Failed to copy config directory"
    cp $src/server.properties $dest/ 2>/dev/null || log "$log_prefix Failed to copy server.properties"
    
    log "$log_prefix Copy attempts completed."
    ls -l $dest/ >> /var/log/entrypoint.log
}

check_server_status() {
    if ! tmux_command has-session -t $TMUX_SESSION 2>/dev/null; then
        log "Tmux session ended. Exiting..."
        return 1
    fi
    return 0
}

tmux_command () {
  if ! tmux $@; then
    log "Failed to execute tmux command: $@"
    return 1
  fi
}

trap 'log "Received SIGTERM/SIGINT"; stop_command; log "Exiting"; exit 0' SIGTERM SIGINT

case "$1" in
  start)
    start_command
    ;;
  stop)
    stop_command
    ;;
  *)
    exec "$@"
    ;;
esac

log "Entrypoint script exiting"
