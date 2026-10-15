# MiniMax H3 长视频工作流 v7.5b 云平台部署包

用来在云平台（Linux）上一键部署本地的 MiniMax H3 长视频工作流。插件、模型、中文字体、工作流全部自动装好，装完自动重启 ComfyUI。

下面所有「在终端里粘贴」的命令，都是指：在平台实例页面点「JupyterLab」，在启动页点「终端」，把命令粘贴进去，按回车。

## 一、第一次部署

### 第 1 步：开机

在平台上新建实例：

- 镜像：选「ComfyUI 纯净版」，CUDA 选 13.2 或 13.0。
- 显卡：选 40 系或 50 系（比如 4090、5090）。租 50 系时，框架版本选带「5090」字样的。不要选 V100 这类老显卡，工作流用的加速功能它都不支持。
- 磁盘：系统盘选 100GB。模型和插件一共要用 55GB 左右，默认的 50GB 不够。以后还要用 fl2va 模型的话，再多留 25GB。

### 第 2 步：在终端里粘贴这一行

```bash
cd ~ && (git clone https://github.com/ironman5-tech/comfyui-h3-cloud.git || git -C comfyui-h3-cloud pull) && bash comfyui-h3-cloud/setup_cloud.sh
```

脚本会自动完成下面这些事。模型一共约 45GB，按网速大约要 40 分钟到 1 小时，中途不用操作：

1. 把 ComfyUI 切换到 v0.38.2（和本地电脑一致），安装依赖。
2. 安装两个自己的插件：本地改过的导演台、H3-BatchShots。
3. 下载两个官方插件：KJNodes、LoRA Manager。
4. 安装 SageAttention 和中文字体（思源黑体，字幕烧录进画面要用）。
5. 下载工作流要用的全部模型。
6. 把工作流放进 ComfyUI 左侧的「工作流」列表。
7. 重启 ComfyUI，让新装的插件生效。

运行开头会显示三行信息，看一眼：

- 「ComfyUI 目录」：一般是 /root/ComfyUI；
- 「使用的 Python」：一般是 /root/miniconda3/bin/python；
- 显卡名称：确认是你租的显卡。

最后会显示「全部完成」，或者列出哪几处没成功。没成功时，看第六部分「常见问题」，处理好后再粘贴同一行命令。已经完成的部分会自动跳过，模型下载到一半中断的会接着下。

### 第 3 步：打开工作流，关掉 Sage 节点

1. 回到 ComfyUI 网页，按 F5 刷新。
2. 在左侧「工作流」里打开 v7.5b 云平台版。
3. **找到「Sage 注意力 KJ（auto）」节点，用鼠标点一下选中它，按 Ctrl+B。** 节点变成紫色，就表示关掉了（ComfyUI 里叫「旁路」）。这个节点在左边「模型 / LoRA」那一组里，「注意力后端：comfy kitchen」下面。
4. 把导演台用到的参考图和参考音频，上传到 /root/ComfyUI/input 文件夹（在 JupyterLab 左边文件列表里打开这个文件夹，把文件拖进去）。
5. 导演台「选择运行」里先只勾第 1 段，点「运行」，确认能出片。

为什么要关掉 Sage：在云平台的 Linux 上，「Sage 注意力 KJ」节点和 ComfyUI 0.38 自带的一个后台优化功能合不来，开着会报错「Cannot access data pointer of Tensor that doesn't have storage」。关掉以后，「注意力后端：comfy kitchen」节点照样在加速。这个节点保留在工作流里，没有删掉，以后 ComfyUI 或 SageAttention 更新修好了这个问题，再按一次 Ctrl+B 就能重新打开。本地 Windows 电脑上一般不受影响。

### 第 4 步：保存镜像

确认能正常出片后，把这台机器保存成镜像，下次开机就不用再部署了。

1. 等 ComfyUI 右上角显示「0 个活动任务」。
2. 要保留的成片先下载到自己电脑（方法见第三部分）。
3. 在终端里粘贴下面这段，清掉测试产生的文件，让镜像小一些（成片没下载的话先别运行）：

```bash
rm -rf /root/ComfyUI/output/minimax_seg_cache /root/ComfyUI/output/minimax_seg_export /root/ComfyUI/output/H3导演台 /root/.cache/pip
du -sh /root
```

4. 回到平台实例页面，点「更多操作」，选「保存镜像」（有的平台叫「制作镜像」）。
5. 状态显示「镜像制作中」时，不要在服务器里跑工作流或运行命令，也不要关机。ComfyUI 和 JupyterLab 的网页可以关掉。
6. 状态变回「运行中」，就是做好了。可以到平台的「镜像」页面确认新镜像在列表里。
7. 不用的话点「关机」，关机后不收实例费。

## 二、以后再用

新建实例或开机时，镜像选你保存的那个，不要再选「ComfyUI 纯净版」。开机后插件、模型、字体都在，直接打开 ComfyUI 和 v7.5b 工作流就能用。

如果 GitHub 仓库里的插件或脚本更新了，在终端里再粘贴一次第一部分的部署命令就会更新。

## 三、成片保存在哪、怎么下载

拼接好的成片在：

```
/root/ComfyUI/output/H3导演台/<项目名>/v1/
```

每拼接一次就新建一个文件夹，v1、v2、v3 依次往后排。里面有：完整版.mp4、完整版_字幕.mp4（字幕烧进画面的版本）、字幕文件、工作流.png、说明.txt。

每段的分段缓存在 `/root/ComfyUI/output/minimax_seg_cache`。拼接和「只重跑某几段」都要用到它，作品定稿前不要删。

下载方法：

- 在 JupyterLab 左边文件列表里依次打开 ComfyUI → output → H3导演台 → 项目名 → v1，在文件上点右键，选「下载」。
- 文件多时，先在终端里打成压缩包（把「项目名」换成实际的文件夹名）：

```bash
cd /root/ComfyUI/output/H3导演台 && zip -r /root/成片.zip 项目名
```

然后在 JupyterLab 左边的 /root 下面找到「成片.zip」，右键下载。

## 四、常用命令

### 重启 ComfyUI

新版 ComfyUI 的管理器里没有重启按钮，在终端里粘贴：

```bash
bash ~/comfyui-h3-cloud/restart_comfyui.sh
```

它会关掉 ComfyUI，用原来的方式重新启动，并等到网页能打开为止（最多 3 分钟）。看到「ComfyUI 已经启动好了」后，回到网页按 F5 刷新。

如果这个办法不行，就在平台实例页面点「关机」，关好后再点「开机」。

### 查看生成速度

一段跑完后，在终端里粘贴：

```bash
tr '\r' '\n' < /root/comfyui.log | grep -oE "[0-9.]+(s/it|it/s)" | tail -n 3; grep "Prompt executed" /root/comfyui.log | tail -n 1
```

- 「xx s/it」：每一步要几秒，比如「9.8s/it」就是每步 9.8 秒；
- 「Prompt executed in xxx seconds」：这一次运行一共花了多少秒。

### 查看 ComfyUI 在做什么

右上角任务看着像卡住了，在终端里粘贴：

```bash
tail -n 8 /root/comfyui.log
```

显卡使用率是 0%、CPU 很高，一般是右边「拼接」节点在合成完整视频、往画面里烧字幕，这一步只用 CPU，视频长的话要几分钟，等一等就好。

## 五、附：开 Sage 到底能快多少（还没测过）

关掉 Sage 以后还有 comfy kitchen 在加速，所以不一定慢很多。想知道开 Sage 能快多少，可以这样对比。不测也不影响正常使用。

1. **先测现在的设置（不开 Sage）**：导演台只勾第 1 段运行，跑完用上面「查看生成速度」的命令，记下 s/it。
2. **再测开 Sage**：在工作流里选中「Sage 注意力 KJ」节点，按 Ctrl+B 让它恢复正常颜色。然后在终端里粘贴下面这行，它会关掉 ComfyUI 的后台优化功能再重启（两者不能同时开）：

```bash
bash ~/comfyui-h3-cloud/restart_comfyui.sh --disable-comfy-compiler
```

刷新网页后，再跑一次第 1 段，记下 s/it。

3. **恢复默认**：测完后在终端里粘贴下面这行，就会恢复默认设置：

```bash
bash ~/comfyui-h3-cloud/restart_comfyui.sh
```

如果第 2 步提示「平台自动启动时不会带上你加的参数」，说明这个平台会自己拉起 ComfyUI，参数加不上，这个对比就做不了。

## 六、常见问题

| 现象 | 原因 | 怎么处理 |
|---|---|---|
| 部署时显示「磁盘空间不够，没有下载模型」 | 系统盘太小 | 在平台上把系统盘扩到 100GB，再粘贴部署命令 |
| 部署时显示「ComfyUI 依赖安装失败」 | 平台默认的 pip 源（如清华镜像）没同步到新版本的包。脚本会自动改用官方 PyPI 重试，重试也失败才会显示这条 | 粘贴 `python -m pip install -r /root/ComfyUI/requirements.txt -i https://pypi.org/simple`，看最后一行是否成功 |
| 运行时报错「Cannot access data pointer of Tensor that doesn't have storage」 | 「Sage 注意力 KJ」节点没有关 | 选中这个节点，按 Ctrl+B 旁路，见第一部分第 3 步 |
| 烧进画面的中文字幕变成方框 | 中文字体没装上（部署结束时会提示） | 粘贴下面「补装中文字体」的命令 |
| 打开工作流后，节点参数名显示「UNKNOWN」、带红框 | 插件装好了，但 ComfyUI 还没重启 | 运行「重启 ComfyUI」的命令，再刷新网页 |
| 管理器里「未解析节点」显示 2 | 导演台和拼接是自己的插件，插件商店里查不到 | 不用管 |
| 日志里很多「LoRA-Manager … Read-only file system」 | LoRA Manager 在给平台自带的只读公共模型建索引 | 不影响使用，不用管 |
| 部署时出现「xformers requires torch==2.8.0」 | 平台镜像里原本就有的版本冲突 | 工作流用不到 xformers，不用管 |
| 部署时出现「models/loras/.gitattributes: Too many levels of symbolic links」 | 平台对 loras 文件夹做了特殊链接 | 不影响使用，不用管 |

### 补装中文字体

```bash
mkdir -p /usr/share/fonts/noto && wget -q --show-progress -O /usr/share/fonts/noto/NotoSansSC-Regular.otf https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf && (command -v fc-cache >/dev/null && fc-cache -f; true) && echo "字体装好了"
```

装好后，已经拼好的成片不用重新生成，把字幕重新烧进最新一次成片即可：

```bash
d=$(ls -td /root/ComfyUI/output/H3导演台/*/v* | head -n 1); echo "处理文件夹：$d"
cd "$d" && $(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())") -y -v error -i 完整版.mp4 -vf "subtitles=完整版_全部字幕.ass" -c:a copy 完整版_字幕.mp4 && echo "字幕已重新烧进画面"
```

## 七、更多设置

### 用 t2v、i2v、fl2v 等模式

导演台用这些模式时，扩散模型要换成 fl2va 版本。这个模型默认不下载，需要时在终端里粘贴：

```bash
cd ~ && WITH_FL2VA=1 bash comfyui-h3-cloud/setup_cloud.sh
```

下载好后，在工作流「扩散模型」节点的下拉框里选 `minimax_h3_fl2va_pruned_int8_convrot.safetensors`。r2v、rv2v 模式用默认的 ref2va 模型。

### 自动下载的模型

全部来自 Hugging Face 官方仓库。国内连不上 Hugging Face 时，脚本会自动改用镜像站 hf-mirror.com。

| 用途 | 文件 | 大小 |
|---|---|---|
| 扩散模型（r2v、rv2v 模式） | minimax_h3_ref2va_pruned_int8_convrot.safetensors | 21GB |
| 文本编码器 | qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors | 15.7GB |
| 视频 VAE | minimax_h3_video_vae_fp16.safetensors | 5.2GB |
| 音频 VAE | minimax_h3_audio_vae_fp32.safetensors | 0.6GB |
| 加速 LoRA（turbo 8 步） | minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors | 2GB |

### 部署脚本的可选开关

写在 `bash` 前面，比如 `SKIP_MODELS=1 bash comfyui-h3-cloud/setup_cloud.sh`：

| 开关 | 作用 |
|---|---|
| `WITH_FL2VA=1` | 额外下载 fl2va 模型 |
| `SKIP_MODELS=1` | 不下载模型，只装插件 |
| `SKIP_RESTART=1` | 部署完不自动重启 ComfyUI |

## 八、仓库里有什么

| 文件 | 内容 |
|---|---|
| `setup_cloud.sh` | 一键部署脚本 |
| `restart_comfyui.sh` | 重启 ComfyUI 的小脚本 |
| `custom_nodes.zip` | 两个无法直接从网上获取的插件：本地改过的导演台（加了“段间防偏色”）和自己写的 H3-BatchShots（分镜导入、分段拼接、字幕） |
| `workflows/` | v7.5b 云平台版工作流 |

云平台版工作流和本地 v7.5 的区别：

1. 删掉了本地默认关着的三个节点：DMAD 4 步 LoRA、Sage 省显存注意力、Spark 稀疏注意力。所以云上不用装 Spark 插件，也不用按显卡型号选 Spark 版本。
2. 模型全部换成上面表里的官方文件，方便脚本自动下载。
3. LoRA 路径从 Windows 的反斜杠改成了 Linux 的正斜杠。

以后在本地改了插件：重新打包 `custom_nodes.zip`，上传到这个仓库覆盖旧文件，云上再粘贴一次部署命令就会更新。

## 九、更新记录

- 2026-10-16：pip 装不上时自动改用官方 PyPI；下载模型时不再升级 huggingface_hub（避免和 transformers 冲突）；中文字体改为直接下载思源黑体；部署完自动重启 ComfyUI；新增重启脚本 restart_comfyui.sh；README 补充磁盘要求、关闭 Sage 节点、保存镜像、常用命令和常见问题。
- 2026-10-15：第一版。模型全部改用官方文件，部署脚本自动下载模型。
