#!/usr/bin/env bash
# MiniMax H3 长视频工作流（v7.5 云平台版）一键部署脚本
#
# 用法（在云服务器的终端里）：
#   bash setup_cloud.sh                 # 自动查找 ComfyUI 目录
#   bash setup_cloud.sh /root/ComfyUI   # 手动指定 ComfyUI 目录
#
# 可选环境变量：
#   PYTHON=/path/to/python   ComfyUI 用的 Python，默认用当前环境里的 python
#   COMFY_VERSION=v0.38.2    要切换到的 ComfyUI 版本，默认和本地电脑一致
#
# 脚本做的事：
#   1. 把 ComfyUI 本体切换到 v0.38.2（和本地一致），安装它的依赖
#   2. 解压本仓库里的两个插件：改过的导演台、H3-BatchShots
#   3. 从 GitHub 下载两个官方插件：KJNodes、LoRA Manager
#   4. 安装 SageAttention 和中文字体（字幕烧录要用）
#   5. 建好模型文件夹，提示还缺哪些模型
# 已经装过的同名插件会先移到 custom_nodes_backup 文件夹，不会直接覆盖。

set -u

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_VERSION="${COMFY_VERSION:-v0.38.2}"
STAMP="$(date +%Y%m%d_%H%M%S)"

say()  { echo -e "\n\033[1;32m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[注意] $*\033[0m"; }

# 国内平台（如 AutoDL）有“学术加速”，能加快访问 GitHub。有就打开。
if [ -f /etc/network_turbo ]; then
    say "检测到平台学术加速，已打开"
    # shellcheck disable=SC1091
    source /etc/network_turbo
fi

# ---------- 找到 ComfyUI 目录 ----------
COMFY_DIR="${1:-}"
if [ -z "$COMFY_DIR" ]; then
    for d in /root/ComfyUI /workspace/ComfyUI /root/autodl-tmp/ComfyUI "$HOME/ComfyUI" /ComfyUI /opt/ComfyUI; do
        if [ -f "$d/main.py" ]; then COMFY_DIR="$d"; break; fi
    done
fi
if [ -z "$COMFY_DIR" ]; then
    COMFY_DIR="$(find / -maxdepth 4 -name main.py -path '*ComfyUI*' 2>/dev/null | head -n 1 | xargs -r dirname)"
fi
if [ -z "$COMFY_DIR" ] || [ ! -f "$COMFY_DIR/main.py" ]; then
    echo "没有找到 ComfyUI 目录。请这样运行：bash setup_cloud.sh /你的/ComfyUI/路径"
    exit 1
fi
say "ComfyUI 目录：$COMFY_DIR"

# ---------- 确定 Python ----------
if [ -z "${PYTHON:-}" ]; then
    if [ -x "$COMFY_DIR/venv/bin/python" ]; then PYTHON="$COMFY_DIR/venv/bin/python"
    elif [ -x "$COMFY_DIR/.venv/bin/python" ]; then PYTHON="$COMFY_DIR/.venv/bin/python"
    elif command -v python >/dev/null 2>&1; then PYTHON="$(command -v python)"
    else PYTHON="$(command -v python3)"
    fi
fi
say "使用的 Python：$PYTHON"
"$PYTHON" -c "import torch; print('torch', torch.__version__, '| CUDA', torch.version.cuda, '| 显卡', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '未检测到')"
PIP=("$PYTHON" -m pip install)

# ---------- 1. 切换 ComfyUI 版本 ----------
say "1/5 切换 ComfyUI 到 $COMFY_VERSION"
if [ -d "$COMFY_DIR/.git" ]; then
    git -C "$COMFY_DIR" fetch --tags --quiet origin || warn "拉取版本信息失败，检查网络后重试"
    if git -C "$COMFY_DIR" checkout --quiet "$COMFY_VERSION"; then
        echo "当前版本：$(git -C "$COMFY_DIR" describe --tags 2>/dev/null)"
    else
        warn "切换失败。如果你在这个 ComfyUI 里改过文件，先执行 git -C $COMFY_DIR stash 再重跑本脚本"
    fi
else
    warn "这个 ComfyUI 不是用 git 安装的，脚本无法自动升级。请在平台上选更新的镜像，或用 ComfyUI-Manager 升级到 0.38.2 以上"
fi
"${PIP[@]}" -r "$COMFY_DIR/requirements.txt"

NODES_DIR="$COMFY_DIR/custom_nodes"
mkdir -p "$NODES_DIR"

# 已有同名插件时先移到 custom_nodes 外面的备份文件夹，ComfyUI 不会再加载它
BACKUP_DIR="$COMFY_DIR/custom_nodes_backup"
backup_if_exists() {
    if [ -e "$NODES_DIR/$1" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$NODES_DIR/$1" "$BACKUP_DIR/$1_$STAMP"
        echo "已有 $1，已移到 custom_nodes_backup/$1_$STAMP"
    fi
}

# ---------- 2. 解压自己的两个插件 ----------
say "2/5 安装导演台（本地改过的版本）和 H3-BatchShots"
backup_if_exists "ComfyUI_MiniMaxH3_Director"
backup_if_exists "ComfyUI-H3-BatchShots"
"$PYTHON" - "$KIT_DIR/custom_nodes.zip" "$NODES_DIR" <<'EOF'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
EOF
"${PIP[@]}" -r "$NODES_DIR/ComfyUI_MiniMaxH3_Director/requirements.txt"

# ---------- 3. 官方插件 ----------
say "3/5 下载官方插件：KJNodes、LoRA Manager"
clone_plugin() {
    local url="$1" name="$2"
    backup_if_exists "$name"
    if git clone --depth 1 "$url" "$NODES_DIR/$name"; then
        [ -f "$NODES_DIR/$name/requirements.txt" ] && "${PIP[@]}" -r "$NODES_DIR/$name/requirements.txt"
    else
        warn "$name 下载失败，检查网络后重跑本脚本"
    fi
}
clone_plugin https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes
clone_plugin https://github.com/willmiao/ComfyUI-Lora-Manager.git comfyui-lora-manager

# ---------- 4. SageAttention 和中文字体 ----------
say "4/5 安装 SageAttention（工作流里「Sage 注意力 KJ」节点要用）"
"${PIP[@]}" sageattention || warn "SageAttention 安装失败。可以先把「Sage 注意力 KJ」节点旁路（Ctrl+B），其余照常运行"

say "安装中文字体（字幕烧录进画面要用，否则中文可能显示成方块）"
if command -v apt-get >/dev/null 2>&1; then
    SUDO=""; [ "$(id -u)" != "0" ] && SUDO="sudo"
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq fonts-noto-cjk fontconfig && fc-cache -f >/dev/null \
        || warn "中文字体安装失败，字幕烧录可能显示方块；srt 字幕文件不受影响"
fi

# ---------- 5. 模型文件夹 ----------
say "5/5 建模型文件夹并检查模型"
M="$COMFY_DIR/models"
mkdir -p "$M/diffusion_models" "$M/text_encoders" "$M/vae" "$M/loras/minimax h3/boost"
cp -n "$KIT_DIR"/workflows/*.json "$COMFY_DIR/user/default/workflows/" 2>/dev/null \
    || { mkdir -p "$COMFY_DIR/user/default/workflows" && cp -n "$KIT_DIR"/workflows/*.json "$COMFY_DIR/user/default/workflows/"; }

check() {
    if ls "$1" >/dev/null 2>&1; then echo "  [有] $1"; else echo "  [缺] $1"; fi
}
echo "工作流需要的模型（缺的请按 README 下载或上传）："
check "$M/diffusion_models/pinkcherryMinimaxH3_v18Hybrid_int8.safetensors"
check "$M/text_encoders/minimaxH3_h3Comfy_nvfp4.safetensors"
check "$M/vae/minimax_h3_video_vae_fp16.safetensors"
check "$M/vae/minimax_h3_audio_vae_fp32.safetensors"
check "$M/loras/minimax h3/boost/minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors"

say "部署完成。启动 ComfyUI 后，在左侧「工作流」里打开 v7.5 云平台版。"
echo "确认能正常出片后，记得在平台上把实例保存成镜像。"
