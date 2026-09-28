#!/bin/bash
# ==============================================================================
# Paperclip Multi-Agent Fleet - Stop Script
# ==============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$DIR/run.pid"

echo "[Paperclip] 正在停止服务..."

if [ -f "$PID_FILE" ]; then
    while read -r pid; do
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            echo "[Paperclip] 停止进程 $pid..."
            kill "$pid" 2>/dev/null || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

pkill -f "paperclipai run" || true
pkill -f "TCP-LISTEN:3101" || true

echo "[Paperclip] ✅ 服务已停止。"
