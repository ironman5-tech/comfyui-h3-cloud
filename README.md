# MiniMax H3 长视频工作流 v7.5b 云平台部署包

用来在云平台（Linux）上一键部署本地的 MiniMax H3 长视频工作流。插件、模型、工作流全部自动装好。

## 一键部署

### 第 1 步：开机

在平台上选「ComfyUI 纯净版」镜像，CUDA 选 13.2 或 13.0。

- 租 RTX 50 系显卡：框架版本选带「5090」字样的。
- 其他显卡：选普通版本。
- 显存建议 24GB 以上。
- 磁盘至少留出 50GB 空间放模型。如果用 fl2va 模型，要 70GB。

### 第 2 步：在终端里粘贴这一行，回车

```bash
cd ~ && (git clone https://github.com/ironman5-tech/comfyui-h3-cloud.git || git -C comfyui-h3-cloud pull) && bash comfyui-h3-cloud/setup_cloud.sh
```

脚本会自动完成下面这些事，模型总共约 45GB，按网速可能要几十分钟：

1. 把 ComfyUI 切换到 v0.38.2（和本地电脑一致），安装依赖。
2. 安装两个自己的插件：本地改过的导演台、H3-BatchShots。
3. 下载两个官方插件：KJNodes、LoRA Manager。
4. 安装 SageAttention 和中文字体（字幕烧录进画面要用）。
5. 下载工作流要用的全部模型。国内连不上 Hugging Face 时会自动改用镜像站。
6. 把工作流放进 ComfyUI 左侧的「工作流」列表。

最后会显示「全部完成」，或者列出哪几处没成功。没成功时，处理好问题后再粘贴同一行命令即可。已经完成的部分会自动跳过，模型下载到一半中断的会接着下。

### 第 3 步：重启 ComfyUI，打开工作流

1. 在平台上重启 ComfyUI，新装的插件要重启才生效。
2. 在左侧「工作流」里打开 v7.5b 云平台版。
3. 把导演台用到的参考图和参考音频（首帧图、四视图、参考音频）上传到 ComfyUI 的 input 文件夹。
4. 先跑一段短的，确认能出片。

### 第 4 步：保存镜像

确认能正常出片后，在平台上把实例保存成镜像。下次直接用这个镜像开机，插件和模型都在。

## 自动下载的模型

全部来自 Hugging Face 的官方仓库：

| 用途 | 文件 | 大小 |
|---|---|---|
| 扩散模型（r2v、rv2v 模式） | minimax_h3_ref2va_pruned_int8_convrot.safetensors | 21GB |
| 文本编码器 | qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors | 15.7GB |
| 视频 VAE | minimax_h3_video_vae_fp16.safetensors | 5.2GB |
| 音频 VAE | minimax_h3_audio_vae_fp32.safetensors | 0.6GB |
| 加速 LoRA（turbo 8 步） | minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors | 2GB |

导演台用 t2v、i2v、fl2v 等模式时，扩散模型要换成 fl2va 版本。这个模型默认不下载。需要时在命令里加上 `WITH_FL2VA=1`：

```bash
cd ~ && WITH_FL2VA=1 bash comfyui-h3-cloud/setup_cloud.sh
```

下载好以后，在工作流「扩散模型」节点的下拉框里选 `minimax_h3_fl2va_pruned_int8_convrot.safetensors`。

## 仓库里有什么

| 文件 | 内容 |
|---|---|
| `custom_nodes.zip` | 两个无法直接从网上获取的插件：本地改过的导演台（加了“段间防偏色”）和自己写的 H3-BatchShots（分镜导入、分段拼接、字幕） |
| `setup_cloud.sh` | 一键部署脚本 |
| `workflows/` | v7.5b 云平台版工作流 |

## 云平台版工作流和本地 v7.5 的区别

1. 删掉了本地默认旁路（关着）的三个节点：DMAD 4 步 LoRA、Sage 省显存注意力、Spark 稀疏注意力。所以云上不用装 Spark 插件，也不用按显卡型号选 Spark 版本。
2. 实际在用的加速节点没变：注意力后端（comfy kitchen）→ Sage 注意力 KJ（auto）→ turbo 8 步 LoRA。
3. 模型全部换成上表里的官方文件，方便脚本自动下载。
4. LoRA 路径从 Windows 的反斜杠改成了 Linux 的正斜杠。

## 常见问题

- 显示「磁盘空间不够」：在平台上给实例扩容磁盘，然后重跑命令。
- 「Sage 注意力 KJ」节点报错：SageAttention 没装好。可以先选中这个节点按 Ctrl+B 旁路，其余照常运行，只是慢一些。
- 烧进画面的中文字幕变成方块：中文字体没装上。执行 `apt-get install -y fonts-noto-cjk` 后，再点一次拼接。
- 下载 GitHub 很慢：国内平台一般有“学术加速”功能，脚本检测到会自动打开。

## 以后改了本地插件怎么同步

在本地改完插件后，重新打包 `custom_nodes.zip`，上传到这个仓库覆盖旧文件。云上再粘贴一次一键部署那行命令就会更新。
