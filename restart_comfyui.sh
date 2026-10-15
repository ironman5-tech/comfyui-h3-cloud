#!/usr/bin/env bash
# 重启 ComfyUI
#
# 用法（在云服务器终端里）：
#   bash ~/comfyui-h3-cloud/restart_comfyui.sh                          # 普通重启
#   bash ~/comfyui-h3-cloud/restart_comfyui.sh --disable-comfy-compiler  # 关掉 ComfyUI 后台优化功能再启动（测 Sage 速度时用）
#
# 做法：记下 ComfyUI 当前的启动方式，关掉它，再用同样的方式启动。
# 普通重启时会去掉上一次加的 --disable-comfy-compiler，恢复默认设置。
# 日志写到 /root/comfyui.log。

LOG=/root/comfyui.log
EXTRA_ARGS=("$@")

PID="$(pgrep -f "main.py.*--listen" | head -n 1)"

if [ -n "$PID" ]; then
    COMFY_DIR="$(readlink -f "/proc/$PID/cwd")"
    PYTHON_BIN="$(readlink -f "/proc/$PID/exe")"
    # 取出原来的启动参数（main.py 后面的部分），去掉 --disable-comfy-compiler
    read -r -a OLD_ARGS <<< "$(tr '\0' ' ' < "/proc/$PID/cmdline" | sed -E 's/.*main\.py//; s/--disable-comfy-compiler//g')"
    echo "当前 ComfyUI：$COMFY_DIR（进程号 $PID）"
    pkill -f "main.py.*--listen"
    sleep 10
else
    COMFY_DIR=""
    for d in /root/ComfyUI /workspace/ComfyUI /root/autodl-tmp/ComfyUI "$HOME/ComfyUI"; do
        if [ -f "$d/main.py" ]; then COMFY_DIR="$d"; break; fi
    done
    PYTHON_BIN="$(command -v python || command -v python3)"
    OLD_ARGS=(--listen 0.0.0.0 --port 8188 --enable-manager)
    echo "ComfyUI 当前没有在运行，将直接启动：$COMFY_DIR"
fi

if [ -z "$COMFY_DIR" ] || [ ! -f "$COMFY_DIR/main.py" ]; then
    echo "没有找到 ComfyUI 目录，无法启动。"
    exit 1
fi

# 有的平台会自动把 ComfyUI 拉起来；这种情况下不再重复启动
if pgrep -f "main.py.*--listen" >/dev/null; then
    echo "平台已经自动重新启动了 ComfyUI。"
    if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
        echo "[注意] 平台自动启动时不会带上你加的参数：${EXTRA_ARGS[*]}"
    fi
else
    cd "$COMFY_DIR" || exit 1
    nohup "$PYTHON_BIN" -u main.py "${OLD_ARGS[@]}" "${EXTRA_ARGS[@]}" > "$LOG" 2>&1 &
    echo "已启动：$PYTHON_BIN -u main.py ${OLD_ARGS[*]} ${EXTRA_ARGS[*]}"
fi

# 等网页能打开，最多等 3 分钟
PORT="$(printf '%s\n' "${OLD_ARGS[@]}" | grep -A1 -x -- '--port' | tail -n 1)"
PORT="${PORT:-8188}"
echo "等待 ComfyUI 启动（最多 3 分钟）……"
for _ in $(seq 1 36); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT"; then
        echo "ComfyUI 已经启动好了，回到网页按 F5 刷新即可。"
        if grep -q "IMPORT FAILED" "$LOG" 2>/dev/null; then
            echo "[注意] 有插件加载失败："
            grep "IMPORT FAILED" "$LOG"
        fi
        exit 0
    fi
    sleep 5
done
echo "[注意] 3 分钟内没等到 ComfyUI 启动。日志最后几行："
tail -n 20 "$LOG"
exit 1
