#!/usr/bin/env bash
# MiniMax H3 长视频工作流（v7.5b 云平台版）一键部署脚本
# 脚本版本：2026-10-16（pip 装不上自动改用官方源、不再升级 huggingface_hub、
#           中文字体改为直接下载、部署完自动重启 ComfyUI）
#
# 一般不用直接运行这个文件，用 README 里那一行命令即可。
# 手动运行：
#   bash setup_cloud.sh                 # 自动查找 ComfyUI 目录
#   bash setup_cloud.sh /root/ComfyUI   # 手动指定 ComfyUI 目录
#
# 可选开关（写在命令前面，例如 WITH_FL2VA=1 bash setup_cloud.sh）：
#   WITH_FL2VA=1     额外下载 fl2va 模型（t2v、i2v、fl2v 等模式要用，约 21GB）
#   SKIP_MODELS=1    不下载模型，只装插件
#   SKIP_RESTART=1   部署完不自动重启 ComfyUI
#   PYTHON=...       指定 ComfyUI 用的 Python，默认自动查找
#   COMFY_VERSION=…  ComfyUI 版本，默认 v0.38.2（和本地电脑一致）
#
# 脚本做的事：
#   1. 把 ComfyUI 切换到 v0.38.2，安装依赖
#   2. 解压两个自己的插件：改过的导演台、H3-BatchShots
#   3. 下载两个官方插件：KJNodes、LoRA Manager
#   4. 安装 SageAttention 和中文字体（思源黑体）
#   5. 自动下载工作流要用的全部模型（已下载的会跳过，中断后重跑会接着下）
#   6. 把工作流放进 ComfyUI 的工作流列表
#   7. 重启 ComfyUI，让新装的插件生效
# 已经装过的同名插件会先移到 custom_nodes_backup 文件夹，不会直接覆盖。
# 整个脚本可以重复运行。

set -u

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_VERSION="${COMFY_VERSION:-v0.38.2}"
STAMP="$(date +%Y%m%d_%H%M%S)"
FAILED=()

say()  { echo -e "\n\033[1;32m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[注意] $*\033[0m"; FAILED+=("$*"); }

# 国内平台（如 AutoDL）有“学术加速”，能加快访问 GitHub。有就打开。
if [ -f /etc/network_turbo ]; then
    # shellcheck disable=SC1091
    source /etc/network_turbo >/dev/null 2>&1 && say "已打开平台学术加速"
fi

# ---------- 找到 ComfyUI 目录 ----------
COMFY_DIR="${1:-}"
if [ -z "$COMFY_DIR" ]; then
    for d in /root/ComfyUI /workspace/ComfyUI /root/autodl-tmp/ComfyUI "$HOME/ComfyUI" /ComfyUI /opt/ComfyUI; do
        if [ -f "$d/main.py" ]; then COMFY_DIR="$d"; break; fi
    done
fi
if [ -z "$COMFY_DIR" ]; then
    COMFY_DIR="$(find / -maxdepth 4 -name main.py -path '*ComfyUI*' -not -path '*/custom_nodes/*' 2>/dev/null | head -n 1 | xargs -r dirname)"
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

# 先用平台默认的 pip 源安装；国内平台的镜像源有时没同步到最新的包，
# 装不上时自动改用官方 PyPI 再装一次。
pip_install() {
    "${PIP[@]}" "$@" && return 0
    echo "默认 pip 源安装失败，改用官方 PyPI 再试一次……"
    "${PIP[@]}" -i https://pypi.org/simple "$@"
}

# ---------- 1. 切换 ComfyUI 版本 ----------
say "1/7 切换 ComfyUI 到 $COMFY_VERSION"
if [ -d "$COMFY_DIR/.git" ]; then
    git -C "$COMFY_DIR" fetch --tags --quiet origin || warn "拉取 ComfyUI 版本信息失败，检查网络后重跑"
    if git -C "$COMFY_DIR" checkout --quiet "$COMFY_VERSION"; then
        echo "当前版本：$(git -C "$COMFY_DIR" describe --tags 2>/dev/null)"
    else
        warn "ComfyUI 切换版本失败。如果改过 ComfyUI 里的文件，先执行 git -C $COMFY_DIR stash 再重跑"
    fi
else
    warn "这个 ComfyUI 不是用 git 安装的，无法自动升级。请用 ComfyUI-Manager 升级到 0.38.2 以上"
fi
pip_install -r "$COMFY_DIR/requirements.txt" || warn "ComfyUI 依赖安装失败"

NODES_DIR="$COMFY_DIR/custom_nodes"
mkdir -p "$NODES_DIR"

# 本脚本装的插件会放一个标记文件。重跑时：带标记的直接更新；
# 不带标记的同名插件（别处装的）先移到 custom_nodes 外面的备份文件夹，ComfyUI 不会再加载它。
MARK=".installed_by_h3_cloud"
BACKUP_DIR="$COMFY_DIR/custom_nodes_backup"
installed_by_us() { [ -f "$NODES_DIR/$1/$MARK" ]; }
backup_if_exists() {
    if [ -e "$NODES_DIR/$1" ] && ! installed_by_us "$1"; then
        mkdir -p "$BACKUP_DIR"
        mv "$NODES_DIR/$1" "$BACKUP_DIR/$1_$STAMP"
        echo "已有 $1（不是本脚本装的），已移到 custom_nodes_backup/$1_$STAMP"
    fi
}

# ---------- 2. 解压自己的两个插件 ----------
say "2/7 安装导演台（本地改过的版本）和 H3-BatchShots"
for name in ComfyUI_MiniMaxH3_Director ComfyUI-H3-BatchShots; do
    backup_if_exists "$name"
    rm -rf "${NODES_DIR:?}/$name"    # 本脚本以前装的旧版本，直接换成仓库里的新版本
done
"$PYTHON" - "$KIT_DIR/custom_nodes.zip" "$NODES_DIR" <<'EOF'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
EOF
touch "$NODES_DIR/ComfyUI_MiniMaxH3_Director/$MARK" "$NODES_DIR/ComfyUI-H3-BatchShots/$MARK"
pip_install -r "$NODES_DIR/ComfyUI_MiniMaxH3_Director/requirements.txt" || warn "导演台依赖安装失败"

# ---------- 3. 官方插件 ----------
say "3/7 下载官方插件：KJNodes、LoRA Manager"
clone_plugin() {
    local url="$1" name="$2"
    if installed_by_us "$name"; then
        git -C "$NODES_DIR/$name" pull --quiet || warn "$name 更新失败，继续用现有版本"
        return
    fi
    backup_if_exists "$name"
    if git clone --depth 1 "$url" "$NODES_DIR/$name"; then
        touch "$NODES_DIR/$name/$MARK"
        if [ -f "$NODES_DIR/$name/requirements.txt" ]; then
            pip_install -r "$NODES_DIR/$name/requirements.txt" || warn "$name 依赖安装失败"
        fi
    else
        warn "$name 下载失败，检查网络后重跑"
    fi
}
clone_plugin https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes
clone_plugin https://github.com/willmiao/ComfyUI-Lora-Manager.git comfyui-lora-manager

# ---------- 4. SageAttention 和中文字体 ----------
say "4/7 安装 SageAttention（「Sage 注意力 KJ」节点要用）"
pip_install sageattention || warn "SageAttention 安装失败。可以把「Sage 注意力 KJ」节点旁路（Ctrl+B），其余照常运行"

say "安装中文字体（字幕烧录进画面要用）"
# 不用系统软件包安装（有的平台系统软件包本身有问题，会装失败），
# 直接从 GitHub 下载开源的思源黑体（Noto Sans SC）放进系统字体文件夹。
FONT_DIR=/usr/share/fonts/noto
FONT_FILE="$FONT_DIR/NotoSansSC-Regular.otf"
FONT_URL=https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
if [ -s "$FONT_FILE" ]; then
    echo "  [已有] 思源黑体"
else
    mkdir -p "$FONT_DIR"
    if curl -fL --retry 3 -o "$FONT_FILE.part" "$FONT_URL" && mv "$FONT_FILE.part" "$FONT_FILE"; then
        echo "  思源黑体已安装"
    else
        rm -f "$FONT_FILE.part"
        warn "中文字体下载失败，烧进画面的中文字幕可能显示成方块；srt 字幕文件不受影响"
    fi
fi
command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1

# ---------- 5. 下载模型 ----------
M="$COMFY_DIR/models"
mkdir -p "$M/diffusion_models" "$M/text_encoders" "$M/vae" "$M/loras/minimax h3/boost"

# 每行：Hugging Face 仓库 | 仓库里的文件路径 | 放到 models 下的哪个文件夹 | 大约多少 GB
MODELS=(
    "Comfy-Org/MiniMax-H3|diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors|diffusion_models|21"
    "Comfy-Org/MiniMax-H3|text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors|text_encoders|16"
    "Comfy-Org/MiniMax-H3|vae/minimax_h3_video_vae_fp16.safetensors|vae|6"
    "Comfy-Org/MiniMax-H3|vae/minimax_h3_audio_vae_fp32.safetensors|vae|1"
    "lightx2v/Minimax-h3-Turbo|minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors|loras/minimax h3/boost|2"
)
if [ "${WITH_FL2VA:-0}" = "1" ]; then
    MODELS+=("Comfy-Org/MiniMax-H3|diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors|diffusion_models|21")
fi

if [ "${SKIP_MODELS:-0}" = "1" ]; then
    say "5/7 已按设置跳过模型下载"
else
    say "5/7 下载模型（总共约 45GB，按网速可能要几十分钟）"

    # 访问不了 huggingface.co 时自动改用国内镜像站
    if [ -z "${HF_ENDPOINT:-}" ] && ! curl -s -m 8 -o /dev/null https://huggingface.co; then
        export HF_ENDPOINT=https://hf-mirror.com
        echo "huggingface.co 连不上，改用镜像站 $HF_ENDPOINT"
    fi
    # 只在没装时才安装，并限制在 1.0 以下：
    # huggingface_hub 1.0 及以上和 ComfyUI 用的 transformers 不兼容
    "$PYTHON" -c "import huggingface_hub" 2>/dev/null \
        || pip_install -q "huggingface_hub<1.0" || warn "huggingface_hub 安装失败"

    # 先算还要下载多少，和剩余空间比一比
    need_gb=0
    for item in "${MODELS[@]}"; do
        IFS='|' read -r repo path folder gb <<< "$item"
        [ -f "$M/$folder/$(basename "$path")" ] || need_gb=$((need_gb + gb))
    done
    free_gb=$(df -BG --output=avail "$M" | tail -n 1 | tr -dc '0-9')
    echo "还需下载约 ${need_gb}GB，模型所在磁盘剩余 ${free_gb}GB"

    if [ "$need_gb" -gt 0 ] && [ "$free_gb" -lt $((need_gb + 5)) ]; then
        warn "磁盘空间不够，没有下载模型。请在平台上扩容磁盘后重跑本脚本"
    else
        for item in "${MODELS[@]}"; do
            IFS='|' read -r repo path folder gb <<< "$item"
            name="$(basename "$path")"
            target="$M/$folder/$name"
            if [ -f "$target" ]; then
                echo "  [已有] $name"
                continue
            fi
            echo "  [下载] $name（约 ${gb}GB）"
            tmp="$M/.download_tmp"
            mkdir -p "$tmp"
            "$PYTHON" - "$repo" "$path" "$tmp" <<'EOF'
import sys
from huggingface_hub import hf_hub_download
repo, path, tmp = sys.argv[1:4]
hf_hub_download(repo_id=repo, filename=path, local_dir=tmp)
EOF
            if [ -f "$tmp/$path" ]; then
                mv "$tmp/$path" "$target"
            else
                warn "$name 下载失败，重跑本脚本会接着下"
            fi
        done
    fi
fi

# 模型全部下载成功后，清掉临时文件夹
all_ok=1
for item in "${MODELS[@]}"; do
    IFS='|' read -r repo path folder gb <<< "$item"
    [ -f "$M/$folder/$(basename "$path")" ] || all_ok=0
done
[ "$all_ok" = "1" ] && rm -rf "$M/.download_tmp"

# ---------- 6. 工作流 ----------
say "6/7 把工作流放进 ComfyUI 的工作流列表"
mkdir -p "$COMFY_DIR/user/default/workflows"
cp -f "$KIT_DIR"/workflows/*.json "$COMFY_DIR/user/default/workflows/"

# ---------- 7. 重启 ComfyUI ----------
if [ "${SKIP_RESTART:-0}" = "1" ]; then
    say "7/7 已按设置跳过重启。之后请运行：bash $KIT_DIR/restart_comfyui.sh"
else
    say "7/7 重启 ComfyUI，让新装的插件生效"
    bash "$KIT_DIR/restart_comfyui.sh" || warn "ComfyUI 重启没有成功，可以在平台上关机再开机"
fi

# ---------- 结果 ----------
echo
if [ ${#FAILED[@]} -eq 0 ]; then
    say "全部完成。回到 ComfyUI 网页按 F5 刷新，在左侧「工作流」里打开 v7.5b 云平台版。"
    echo "打开后先把「Sage 注意力 KJ」节点旁路（选中后按 Ctrl+B），原因见 README。"
else
    echo -e "\033[1;33m部署结束，但有 ${#FAILED[@]} 处没成功：\033[0m"
    for f in "${FAILED[@]}"; do echo "  - $f"; done
    echo "处理后重跑同一行命令即可，已经完成的部分会自动跳过。"
fi
echo "确认能正常出片后，记得在平台上把实例保存成镜像。"
