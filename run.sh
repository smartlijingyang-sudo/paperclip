#!/bin/bash
# ==============================================================================
# Paperclip Multi-Agent Fleet - One-Click Service Runner
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="/home/lichao/paperclip-data"
PID_FILE="$DIR/run.pid"
NODE_BIN="/home/lichao/.local/node-v24/bin"

export PATH="$NODE_BIN:$PATH"

mkdir -p "$DATA_DIR/instances/default/logs"

# 1. 检查是否已经在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" | head -n 1)
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "[Paperclip] 进程已在运行中 (PID: $OLD_PID)。"
        echo "[Paperclip] 访问地址: http://10.36.6.252:3101 或 http://100.114.119.73:3101"
        exit 0
    fi
fi

echo "[Paperclip] 正在启动 Paperclip 舰队控制台 (Node $(node -v))..."

# 2. 启动核心服务 (监听 127.0.0.1:3100)
if ! curl -s http://127.0.0.1:3100/api/health > /dev/null 2>&1; then
    nohup "$NODE_BIN/paperclipai" run -d "$DATA_DIR" > "$DATA_DIR/instances/default/logs/paperclip.out" 2>&1 &
    SERVER_PID=$!
    disown $SERVER_PID 2>/dev/null || true
else
    SERVER_PID=$(pgrep -f "paperclipai run" | head -n 1 || echo "")
fi

# 3. 启动端口转发 (0.0.0.0:3101 -> 127.0.0.1:3100，支持局域网与 Tailscale)
if ! netstat -tuln | grep -q ":3101 "; then
    nohup socat TCP-LISTEN:3101,fork,reuseaddr TCP:127.0.0.1:3100 > /dev/null 2>&1 &
    SOCAT_PID=$!
    disown $SOCAT_PID 2>/dev/null || true
else
    SOCAT_PID=$(pgrep -f "TCP-LISTEN:3101" | head -n 1 || echo "")
fi

echo "$SERVER_PID" > "$PID_FILE"
echo "$SOCAT_PID" >> "$PID_FILE"

# 4. 探针等待启动就绪
echo "[Paperclip] 等待服务就绪..."
for i in {1..30}; do
    if curl -s -f http://127.0.0.1:3100/api/health > /dev/null 2>&1; then
        echo "[Paperclip] ✅ 核心服务启动就绪！"
        echo "=========================================================="
        echo "  - 局域网访问:   http://10.36.6.252:3101"
        echo "  - Tailscale访问: http://100.114.119.73:3101"
        echo "  - 本机访问:     http://127.0.0.1:3100"
        echo "  - 进程 PID:     Server=$SERVER_PID, Socat=$SOCAT_PID"
        echo "=========================================================="
        exit 0
    fi
    sleep 1
done

echo "[Paperclip] ⚠️ 启动超时，请检查日志: $DATA_DIR/instances/default/logs/paperclip.out"
exit 1
