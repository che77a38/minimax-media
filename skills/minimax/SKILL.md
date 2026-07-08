---
name: minimax
description: Use the bundled MiniMax MCP server to generate images, videos, speech, music, cloned voices, and designed voices. Trigger when the user asks Codex, Claude Code, or Antigravity to "生图 / 出图 / 画一张 / generate an image", "生视频 / generate a video / image-to-video", "TTS / 配音 / 朗读 / 语音合成 / voice clone / voice design / clone my voice / music generation". 触发场景包括用户让模型画图、出视频、做配音、克隆音色、设计新声音、生成音乐。对应官方 MiniMax-AI/MiniMax-MCP 工具：text_to_image、generate_video、query_video_generation、text_to_audio、list_voices、voice_clone、voice_design、music_generation、play_audio。
---

# MiniMax 媒体能力（MCP）

本目录是一个**三平台共用**的插件，同时支持 Codex / Claude Code /
Antigravity。它指向的 MCP 服务器是官方的
[MiniMax-AI/MiniMax-MCP](https://github.com/MiniMax-AI/MiniMax-MCP)（MIT，
[PyPI: minimax-mcp](https://pypi.org/project/minimax-mcp/) v0.0.18+），三家
host 用的是同一个进程与同一组工具。差异只在元数据文件：

```
.codex-plugin/plugin.json           Codex desktop
.claude-plugin/plugin.json          Claude Code（同目录下还有 marketplace.json）
.mcp.json                           三个 host 共享的 stdio MCP 配置
skills/minimax/                     共享的 skill 描述
```

## 环境变量

MCP 启动时读取下面这些环境变量：

| 变量 | 作用 | 默认 |
|---|---|---|
| `MINIMAX_API_KEY` | 控制台拿到的 API key——**必填** | — |
| `MINIMAX_API_HOST` | 国内 / 海外域名 | 国内：`https://api.minimaxi.com`，海外：`https://api.minimax.io` |
| `MINIMAX_MCP_BASE_PATH` | 文件输出目录（`RESOURCE_MODE=local` 时） | `/tmp/minimax-mcp-out` |
| `MINIMAX_API_RESOURCE_MODE` | `url`（返回带签名的 URL）还是 `local`（直接写磁盘） | `url` |
| `MINIMAX_UVX_PATH` | 指定 `uvx` 绝对路径（找不到时用） | 自动探测 |

加到 `~/.zshrc`（或对应 shell 的 profile），再重启 AI host：

```
export MINIMAX_API_KEY="sk-cp-..."
# 二选一：
export MINIMAX_API_HOST="https://api.minimaxi.com"     # 国内
# export MINIMAX_API_HOST="https://api.minimax.io"     # 海外
export MINIMAX_MCP_BASE_PATH="$HOME/Desktop/minimax-output"
export MINIMAX_API_RESOURCE_MODE="url"
```

`.mcp.json` 里每个 env 字段写的是**变量名字符串**，由宿主进程解析。如果
你的 host 版本不会把 env 转发给子进程，就把字面值（key 直接展开）填进
`.mcp.json`（即把 `"MINIMAX_API_KEY"` 替换成真的 `sk-cp-...`），但**勿
提交到 git**。

## uvx 启动器

`uvx`（来自 [Astral 的 `uv`](https://docs.astral.sh/uv/)）必须装好。
macOS 上的 Codex desktop 启动 MCP 子进程时常常看不到 `~/.local/bin`，所以
`.mcp.json` 同时支持通过 `MINIMAX_UVX_PATH` 显式指定：

```
export MINIMAX_UVX_PATH="/Users/你/.local/bin/uvx"
```

`scripts/uvx-resolver.sh` 列出了常见安装位置。MCP 入口固定是
`uvx minimax-mcp`。

## 工具 → 意图映射

按用户意图挑最贴合的工具：

- "画一张 / 生成图片 / 做张缩略图" → `text_to_image`
  - 参数：`prompt`，可选 `aspect_ratio`、`n`、`prompt_optimizer`
- "生个视频 / 做个短视频 / 让这张图动起来" → `generate_video`
  - 参数：`prompt`，可选 `model`、`first_frame_image`（路径或 URL）、
    `duration`、`resolution`、`async_mode`
  - 用最新的 `MiniMax-Hailuo-02`（画质最好、最清晰）一般这样配：
    `duration=6` 或 `10`，`resolution="768P"` 或 `"1080P"`
  - 如果调用立刻返回了一个 `task_id`，用 `query_video_generation(task_id=...)`
    每 5–10 秒轮询，直到 `status` 是 `Success` 或 `Fail`。Hailuo-02 冷
    启动较慢，至少等 5 分钟再放弃
- "朗读 / TTS / 配音 / 念这段话" → `text_to_audio`
  - 参数：`text`，可选 `voice_id`、`model`、`speed`、`emotion`、
    `output_directory`
- "克隆我这段录音的声音 / 用某个样本克隆" → `voice_clone`
  - 参数：样本 `file`（路径或 URL）、目标 `voice_id`、`text`，可选
    `is_url`、`output_directory`
  - **国内套餐要求实名认证**，否则服务器会回
    `voice clone user forbidden, should complete real-name verification on
    https://platform.minimaxi.com/user-center/basic-information`
- "设计一个听起来像 X 的声音 / 用描述造一种声音" → `voice_design`
  - 参数：描述性 `prompt`、示例 `preview_text`，可选 `voice_id`、
    `output_directory`
- "做段背景音乐 / 配乐生成" → `music_generation`
  - 参数：`prompt`（风格/情绪）、`lyrics`（用 `[Intro][Verse][Chorus]`
    标签分段）、可选 `sample_rate`、`bitrate`、`format`、`output_directory`
- "有哪些声音可选" → `list_voices`
  - 参数：`voice_type`，取值 `["all", "system", "voice_cloning"]`
- "本地试听刚生成的那段音频" → `play_audio`
  - 配套给 `text_to_audio` / `voice_clone` / `voice_design` 用。需要宿主
    有音频设备：Codex desktop 支持；无头 agent 不支持。

## 产出处理

2026-07-08 用国内套餐 key 实测：MCP 服务器返回的是带签名的 OSS URL
（`*.oss-cn-wulanchabu.aliyuncs.com`，约 10 分钟过期），或者按
`MINIMAX_API_RESOURCE_MODE` 直接落到 `MINIMAX_MCP_BASE_PATH`。两种都要
做以下任一步：

1. 把 URL / 路径用 Markdown 链接形式给到用户；
2. `curl -L` 把它抓回来，放到自己可控的 outputs 目录里，避免 URL 过期
   后产物丢失。

如果开 `async_mode=true` 生成视频，第一次返回的只有 `task_id` —— 等查
询之后才有文件。在给用户回复时不要漏掉这一段轮询逻辑。

## 实测结果（2026-07-08）

国内套餐 key、`RESOURCE_MODE=local`、在 Codex shell 里跑：

| 工具 | 往返耗时 | 产物 |
|---|---|---|
| `text_to_image` | ~21 秒 | 1024×1024 JPEG |
| `generate_video`（6 秒） | ~102 秒 | MP4 |
| `list_voices` | < 1 秒 | 16 个系统音色 + 克隆音色预设 |
| `text_to_audio` | < 1 秒 | MP3，默认音色 `female-shaonv` |
| `voice_design` | ~14 秒 | MP3 + 新 `voice_id` |
| `music_generation` | ~37 秒 | MP3 |
| `voice_clone` | 拒绝 | 国内套餐需先在控制台完成实名认证 |
| `play_audio` | n/a | 需要音频设备，无头环境未测试 |

冒烟测试时的产物已放在 `assets/` 和 `examples/`，方便发版对比。

## 故障排错（请原样转给用户）

- `API Error: invalid api key` → key 与 host 区域不匹配。国内走
  `api.minimaxi.com`，海外走 `api.minimax.io`。
- `voice clone user forbidden, should complete real-name verification` →
  去 MiniMax 控制台完成实名后再试。
- `spawn uvx ENOENT` → 宿主进程看不到 uvx。设 `MINIMAX_UVX_PATH` 为绝对
  路径（如 `/Users/你/.local/bin/uvx`）。
- `play_audio` 报 `Resource temporarily unavailable` → 宿主没有音频设备；
  退化成"返回文件路径让用户自行播放"或转码成可视文件。
- `insufficient_quota` → 提示用户去 MiniMax 控制台充值。

加载本插件后，**不要**用 `curl` 绕过 MCP 直接调 MiniMax REST。服务器
已把同一套接口暴露成 MCP 工具，统一走 MCP 不会出现鉴权/字段不一致问题。
