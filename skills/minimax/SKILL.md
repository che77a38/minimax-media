---
name: minimax
description: Use the bundled MiniMax MCP server to generate images, videos, speech, music, cloned voices, and designed voices. Trigger when the user asks Codex, Claude Code, or Antigravity to "生图 / 出图 / 画一张 / generate an image", "生视频 / generate a video / image-to-video", "TTS / 配音 / 朗读 / 语音合成 / voice clone / voice design / clone my voice / music generation". Maps to the official MiniMax-AI/MiniMax-MCP tools (text_to_image, generate_video, query_video_generation, text_to_audio, list_voices, voice_clone, voice_design, music_generation, play_audio).
---

# MiniMax Media (MCP)

This directory is a **single plugin** that ships to Codex, Claude Code, and
Antigravity at the same time. The MCP server it points at, the official
[MiniMax-AI/MiniMax-MCP](https://github.com/MiniMax-AI/MiniMax-MCP) (MIT,
[minimax-mcp on PyPI](https://pypi.org/project/minimax-mcp/) v0.0.18+), is
identical across all three hosts. The platform-specific config files differ
only by metadata:

```
.codex-plugin/plugin.json        Codex desktop
.claude-plugin/plugin.json       Claude Code (also .claude-plugin/marketplace.json)
.mcp.json                        shared stdio MCP config consumed by all three hosts
skills/minimax/                  shared skill description
```

## Environment

The plugin reads these env vars at MCP server startup:

| var | purpose | default |
|---|---|---|
| `MINIMAX_API_KEY` | the API key from platform.minimax(.chat).com — **required** | — |
| `MINIMAX_API_HOST` | global vs mainland endpoint | mainland: `https://api.minimaxi.com`, global: `https://api.minimax.io` |
| `MINIMAX_MCP_BASE_PATH` | output directory for files (when `RESOURCE_MODE=local`) | `/tmp/minimax-mcp-out` |
| `MINIMAX_API_RESOURCE_MODE` | `url` (return signed URLs) vs `local` (write to disk) | `url` |
| `MINIMAX_UVX_PATH` | override `uvx` location if not on `$PATH` | auto-detect |

Set them in `~/.zshrc` (or equivalent) before reloading your AI host:

```
export MINIMAX_API_KEY="sk-cp-..."
# pick one host:
export MINIMAX_API_HOST="https://api.minimaxi.com"     # mainland
# export MINIMAX_API_HOST="https://api.minimax.io"     # global
export MINIMAX_MCP_BASE_PATH="$HOME/Desktop/minimax-output"
export MINIMAX_API_RESOURCE_MODE="url"
```

`.mcp.json` writes each env value as a plain string matching the env-var
name, so the host resolves it from the AI process environment. **If your host
build does not forward env, drop the resolved value into `.mcp.json`
directly** (replace `"MINIMAX_API_KEY"` with `"eyJ..."` or your plan token).

## uvx launcher

`uvx` (from [Astral's `uv`](https://docs.astral.sh/uv/)) must be installed.
The Codex desktop host on macOS often does not see `~/.local/bin` in spawned
MCP processes, so `.mcp.json` lets you point at an absolute path:

```
export MINIMAX_UVX_PATH="/Users/you/.local/bin/uvx"
```

The repo's `scripts/uvx-resolver.sh` lists common install locations and the
relative MCP entrypoint is `uvx minimax-mcp`.

## Tool → intent map

When the user asks for creative output, pick the smallest tool that fits:

- "画一张 / generate an image / make a thumbnail" → `text_to_image`
  - args: `prompt`, optional `aspect_ratio`, `n`, `prompt_optimizer`
- "生视频 / 做个短视频 / animate this image" → `generate_video`
  - args: `prompt`, optional `model`, `first_frame_image` (path or URL),
    `duration`, `resolution`, `async_mode`
  - for `MiniMax-Hailuo-02` (latest, ultra-clear) you typically pass
    `duration=6` or `10` and `resolution="768P"` or `"1080P"`
  - if the call returns immediately with a `task_id`, poll with
    `query_video_generation(task_id=...)` every 5–10 s until `status` is
    `Success` or `Fail`. Wait at least 5 minutes before giving up — cold
    starts on Hailuo-02 can be slow.
- "朗读 / TTS / 配音 / 念这段话" → `text_to_audio`
  - args: `text`, optional `voice_id`, `model`, `speed`, `emotion`, `output_directory`
- "克隆我这段录音的声音 / clone voice from <audio>" → `voice_clone`
  - args: voice sample `file` (path or URL), target `voice_id`, `text`,
    optional `is_url`, `output_directory`
  - **requires real-name verification on the MiniMax open platform**; otherwise
    the server returns `voice clone user forbidden, should complete real-name
    verification on https://platform.minimaxi.com/user-center/basic-information`.
- "设计一个听起来像 X 的声音 / voice from description" → `voice_design`
  - args: descriptive `prompt`, `preview_text`, optional `voice_id`,
    `output_directory`
- "做一段背景音乐 / music generation" → `music_generation`
  - args: `prompt` (style/mood), `lyrics` (with `[Intro][Verse][Chorus]` tags),
    optional `sample_rate`, `bitrate`, `format`, `output_directory`
- "有哪些声音可选" → `list_voices`
  - args: `voice_type` in `["all", "system", "voice_cloning"]`
- "本地试听刚生成的那段音频" → `play_audio`
  - companion to `text_to_audio` / `voice_clone` / `voice_design`. Requires
    a host that exposes an audio device — Codex desktop supports it, headless
    agents do not.

## Output handling

Verified behaviour with the MiniMax mainland plan key (2026-07-08): the MCP
server returns a **signed HTTPS URL on an OSS bucket**
(`*.oss-cn-wulanchabu.aliyuncs.com`) with ~10-minute expiry, OR writes the
file directly under `MINIMAX_MCP_BASE_PATH` depending on
`MINIMAX_API_RESOURCE_MODE`. Always either:

1. surface the URL/Drive/path to the user as a Markdown link, or
2. `curl -L` it into your outputs folder so the artifact outlives the link.

For videos generated via `async_mode=true`, only the `task_id` is returned
initially — the file lands after you query. Don't broadcast the `task_id`
without also wiring the poll.

## Verified results (2026-07-08)

Smoke test on a Codex shell, mainland plan key, `RESOURCE_MODE=local`:

| tool | round-trip | artifacts |
|---|---|---|
| `text_to_image` | ~21 s | 1024×1024 JPEG |
| `generate_video` (6 s) | ~102 s | MP4 |
| `list_voices` | < 1 s | 16 system voices + cloning presets |
| `text_to_audio` | < 1 s | MP3, default voice `female-shaonv` |
| `voice_design` | ~14 s | MP3 + new `voice_id` |
| `music_generation` | ~37 s | MP3 |
| `voice_clone` | refused | plan key requires 实名认证 on the mainland control panel |
| `play_audio` | n/a | requires audio device; not exercised in headless smoke |

Sample artefacts produced during smoke testing live under `assets/` and
`examples/` in this repo.

## Failure modes to surface verbatim

- `API Error: invalid api key` → key/host region mismatch. Verify both are
  global/global or mainland/mainland.
- `voice clone user forbidden, should complete real-name verification` → go to
  the MiniMax open platform user center and complete verification before
  retrying.
- `spawn uvx ENOENT` → `uvx` not on the host's `$PATH`. Set
  `MINIMAX_UVX_PATH` to an absolute path (e.g. `/Users/you/.local/bin/uvx`).
- `Resource temporarily unavailable` from `play_audio` → host has no audio
  device; remux to a viewable file instead.
- `insufficient_quota` → ask the user to top up at the MiniMax console.

Do not call MiniMax REST endpoints directly via `curl` while this plugin is
loaded — the MCP server is the supported path and exposes the same surface.
