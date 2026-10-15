# MiniMax H3 长视频工作流 v7.5 云平台部署包

这个仓库用来在云平台（Linux）上部署本地的 MiniMax H3 长视频工作流 v7.5。

## 仓库里有什么

| 文件 | 内容 |
|---|---|
| `custom_nodes.zip` | 两个无法直接从网上获取的插件：本地改过的导演台（ComfyUI_MiniMaxH3_Director，加了“段间防偏色”）和自己写的 ComfyUI-H3-BatchShots（分镜导入、分段拼接、字幕） |
| `setup_cloud.sh` | 一键部署脚本 |
| `workflows/` | v7.5 云平台版工作流 |

官方原版插件（KJNodes、LoRA Manager）不放在这里，脚本会直接从 GitHub 下载。

## 云平台版工作流和本地 v7.5 的区别

1. 删掉了本地默认旁路（关着）的三个节点：DMAD 4 步 LoRA、Sage 省显存注意力、Spark 稀疏注意力 SM89。所以云上不需要装 Spark 插件，也不需要按显卡型号选 Spark 版本。
2. 实际在用的加速节点没有变：注意力后端（comfy kitchen）→ Sage 注意力 KJ（auto）→ turbo 8 步 LoRA。
3. LoRA 路径从 Windows 的反斜杠改成了 Linux 的正斜杠（`minimax h3/boost/...`）。

## 部署步骤

### 第 1 步：开机

在平台上选「ComfyUI 纯净版」镜像，CUDA 13.2 或 13.0。租 RTX 50 系显卡选带「5090」字样的框架版本，其他显卡选普通版本。显存建议 24GB 以上。

### 第 2 步：运行部署脚本

打开实例的终端，执行：

```bash
git clone https://github.com/ironman5-tech/comfyui-h3-cloud.git
cd comfyui-h3-cloud
bash setup_cloud.sh
```

脚本会自动找 ComfyUI 目录。找不到时，把路径写在后面：`bash setup_cloud.sh /root/ComfyUI`。

脚本会做这些事：

1. 把 ComfyUI 切换到 v0.38.2（和本地电脑一致），安装依赖。
2. 解压导演台和 H3-BatchShots 两个插件。
3. 下载 KJNodes 和 LoRA Manager 两个官方插件。
4. 安装 SageAttention，以及中文字体（字幕烧录进画面时要用）。
5. 建好模型文件夹，把工作流复制到 ComfyUI 的工作流列表里，最后列出还缺哪些模型。

### 第 3 步：放模型

ComfyUI 纯净版镜像不带任何模型，需要自己放进去。工作流用到 5 个模型文件：

| 文件 | 放到哪个文件夹 | 大小 | 来源 |
|---|---|---|---|
| pinkcherryMinimaxH3_v18Hybrid_int8.safetensors | models/diffusion_models | 十几到二十几 GB | Civitai 上的 PinkCherry MiniMax H3 |
| minimaxH3_h3Comfy_nvfp4.safetensors | models/text_encoders | 约 15.7GB | 和本地下载时同一个来源 |
| minimax_h3_video_vae_fp16.safetensors | models/vae | 约 5.2GB | 和本地下载时同一个来源 |
| minimax_h3_audio_vae_fp32.safetensors | models/vae | 约 0.6GB | 官方：Hugging Face 的 Comfy-Org/MiniMax-H3，vae 文件夹 |
| minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors | models/loras/minimax h3/boost | 约 2GB | 官方：Hugging Face 的 lightx2v/Minimax-h3-Turbo |

建议在服务器上直接下载，比从家里电脑上传快很多。

从 Hugging Face 下载（国内平台用镜像站）：

```bash
export HF_ENDPOINT=https://hf-mirror.com
pip install -U huggingface_hub
cd /root/ComfyUI/models    # 换成你的 ComfyUI 路径
hf download Comfy-Org/MiniMax-H3 vae/minimax_h3_audio_vae_fp32.safetensors --local-dir .
hf download lightx2v/Minimax-h3-Turbo minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16.safetensors --local-dir "loras/minimax h3/boost"
```

如果提示找不到文件，打开对应 Hugging Face 仓库的「Files」页面核对文件路径，再改上面的命令。

从 Civitai 下载：在模型页面的下载按钮上点右键，复制链接，然后：

```bash
cd /root/ComfyUI/models/diffusion_models
wget -O pinkcherryMinimaxH3_v18Hybrid_int8.safetensors "复制的链接?token=你的Civitai令牌"
```

Civitai 令牌在 Civitai 网站「设置 → API Keys」里生成。

如果某个模型在网上找不到了，只能从本地电脑上传（平台的文件上传功能或网盘）。

想用官方模型代替也可以：文本编码器可以换成 Comfy-Org 的 `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors`，视频 VAE 可以换成 `minimax_h3_video_vae_int8_convrot.safetensors`。换了之后要在工作流对应节点的下拉里重新选择。

### 第 4 步：启动并检查

1. 启动 ComfyUI，在左侧「工作流」里打开 v7.5 云平台版。
2. 检查各个模型节点的下拉框里选中的是不是正确的文件。
3. 导演台里的参考图、参考音频（如首帧图、四视图、test_48k.wav）要上传到 ComfyUI 的 input 文件夹。
4. 先跑一段短的确认能出片。

### 第 5 步：保存镜像

确认能正常出片后，在平台上把实例保存成镜像。下次直接用这个镜像开机，插件和模型都在。

## 常见问题

- 「Sage 注意力 KJ」报错：说明 SageAttention 没装好。可以先选中这个节点按 Ctrl+B 旁路，其余照常运行，只是慢一些。
- 字幕烧录后中文变方块：中文字体没装上。执行 `apt-get install -y fonts-noto-cjk` 后重跑拼接。
- 下载 GitHub 或 Hugging Face 很慢：国内平台一般有“学术加速”功能，脚本检测到会自动打开。

## 以后改了本地插件怎么同步

在本地改完插件后，重新打包 `custom_nodes.zip`，上传到这个仓库覆盖旧文件。云上在仓库目录里执行 `git pull`，再执行一次 `bash setup_cloud.sh`。
