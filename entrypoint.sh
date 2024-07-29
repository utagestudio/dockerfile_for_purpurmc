#!/bin/bash
set -e

# start
start_command() {
    echo "Starting the application..."
    tmux new-session -d -s purpur
    tmux send-keys '/run.sh' C-m
    echo "Application started in tmux session"
}

stop_command() {
    echo "Stopping the application..."
    tmux send-keys -t purpur "stop" C-m
    sleep 10
    tmux has-session -t purpur 2>/dev/null && tmux kill-session -t purpur
}

trap stop_command SIGTERM SIGINT

case "$1" in
    start)
        start_command
        while true; do
            tmux has-session -t purpur 2>/dev/null || break
            sleep 1
        done
        ;;
    stop)
        stop_command
        ;;
    *)
        exec "$@"
        ;;
esac