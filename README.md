# MiniMax Media Plugin（MiniMax 媒体插件）

一个 MCP 插件，让 **Codex、Claude Code、Antigravity** 三家 AI 客户端用同
一套配置接入官方 MiniMax 媒体 API。一次 `git clone`，三处可用。

![示例图](assets/sample-panda.jpg)

> 由 `text_to_image` 生成，提示词为 *"a panda astronaut floating in pastel nebula"*（一只漂浮在粉彩星云里的熊猫宇航员）。

---

## 它能做什么

| 工具 | 产出 |
| --- | --- |
| `text_to_image` | 一张静图（默认 1024 × 1024） |
| `generate_video` | 一段 6/10 秒视频，可选首帧 |
| `query_video_generation` | 轮询异步视频任务 |
| `text_to_audio` | TTS 朗读 |
| `list_voices` | 枚举系统音色 + 克隆音色 |
| `voice_clone` | 用一段音频样本克隆声音 |
| `voice_design` | 根据文字描述"设计"一种新声音 |
| `music_generation` | 按提示词 + 歌词生成一段音乐 |
| `play_audio` | 在本地播放已生成的音频 |

插件把一切都委托给官方的
[MiniMax-AI/MiniMax-MCP](https://github.com/MiniMax-AI/MiniMax-MCP)（MIT，
[PyPI: minimax-mcp](https://pypi.org/project/minimax-mcp/)）服务器。本仓库
本身**不**直接发任何网络请求。

---

## 仓库结构

```
.codex-plugin/plugin.json         Codex desktop 元数据 + UI 字段
.claude-plugin/plugin.json        Claude Code 元数据
.claude-plugin/marketplace.json   让 Claude Code 把本仓库注册为一个 marketplace
.mcp.json                         共享的 stdio MCP 配置（三家都认）
skills/minimax/SKILL.md           共享的 skill 描述
scripts/uvx-resolver.sh           帮你在常见路径里找 uvx 的小脚本
assets/                           图标 + 一张示例静图
examples/                         冒烟测试时生成的样本 MP3 / MP4
```

---

## 1. 前置条件

需要：

1. **Python ≥ 3.10**（MCP 服务器基于 `FastMCP`）。
2. **Astral 的 [`uv`](https://docs.astral.sh/uv/)**，它带 `uvx`。
   安装：`curl -LsSf https://astral.sh/uv/install.sh | sh`，然后确认：

   ```bash
   which uvx          # 例如：/Users/you/.local/bin/uvx
   ```

3. **MiniMax 套餐 key**，需包含「生图 / 生视频 / 音色 / 音乐」权限。
   - 国内开通：<https://platform.minimaxi.com>
   - 海外开通：<https://platform.minimax.io>

---

## 2. 配置环境变量

把下面这几行加进 shell profile（`~/.zshrc`、`~/.bashrc`、`~/.config/fish/...`）：

```bash
export MINIMAX_API_KEY="sk-cp-..."        # 控制台显示成什么样就照原样填
export MINIMAX_API_HOST="https://api.minimaxi.com"   # 国内；海外改 https://api.minimax.io
export MINIMAX_MCP_BASE_PATH="$HOME/Desktop/minimax-output"
export MINIMAX_API_RESOURCE_MODE="url"    # 或者 "local" 写到磁盘
# 如果你的 AI host 找不到 uvx，手动指一下：
# export MINIMAX_UVX_PATH="/Users/you/.local/bin/uvx"
chmod 600 ~/.zshrc
```

然后 `source ~/.zshrc`。

---

## 3. 按平台安装

### Codex desktop

> 设置 → Plugins → "Add local plugin" → 选本仓库根目录。

Codex 读 `.codex-plugin/plugin.json`，按 `.mcp.json` 启动 `uvx minimax-mcp`。
装好后随便让 Codex "列出所有音色"，能返回 9 个工具就算成功。

### Claude Code

```bash
# 把本仓库当成 marketplace 加进去，然后安装插件
claude plugin marketplace add /绝对路径/minimax-plugin
claude plugin install minimax --from /绝对路径/minimax-plugin
```

Claude Code 读 `.claude-plugin/plugin.json` 和
`.claude-plugin/marketplace.json`。根目录的 `.mcp.json` 自动生效。

### Antigravity

把本仓库放到 `~/.agents/plugins/minimax/`（软链也行）：

```bash
mkdir -p ~/.agents/plugins
ln -s "$(pwd)" ~/.agents/plugins/minimax
```

Antigravity 与 Claude Code 共用 plugin 加载逻辑，所以同一份文件两边通用。

---

## 4. 验证

`skills/minimax/SKILL.md` 是三家 host 都会载入的描述。在任何一家里说
一句"生一张可爱的熊猫宇航员"，应该能拿到一张图。离线验证：

```bash
ls examples/        # 冒烟测试时生成的样本
```

| 文件 | 来源 |
| --- | --- |
| `examples/sample-video.mp4` | `generate_video` |
| `examples/sample-tts.mp3` | `text_to_audio` |
| `examples/sample-voice-design.mp3` | `voice_design` |
| `examples/sample-music.mp3` | `music_generation` |
| `assets/sample-panda.jpg` | `text_to_image` |

---

## 5. 直接 stdio 自检（不需要任何 AI host）

跑下面这段 Python 可以不打开任何客户端、纯 stdio 跟 MCP 服务器握一次手：

```python
import json, subprocess, os, sys

ENV = os.environ.copy()
proc = subprocess.Popen(
    ["uvx", "minimax-mcp"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    env=ENV,
)
def rpc(method, params=None, _id=[0]):
    _id[0] += 1
    proc.stdin.write((json.dumps({"jsonrpc":"2.0","id":_id[0],"method":method,"params":params or {}})+"\n").encode())
    proc.stdin.flush()
    return json.loads(proc.stdout.readline())

print(rpc("initialize", {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "smoke", "version": "0"},
})["result"]["serverInfo"])
proc.stdin.write((json.dumps({"jsonrpc":"2.0","method":"notifications/initialized"})+"\n").encode())
proc.stdin.flush()
print([t["name"] for t in rpc("tools/list")["result"]["tools"]])
proc.terminate()
```

---

## 故障排查

| 现象 | 原因 | 解决 |
| --- | --- | --- |
| `spawn uvx ENOENT` | 找不到 uvx | `scripts/uvx-resolver.sh` 找到位置，设 `MINIMAX_UVX_PATH`，或把绝对路径直接写进 `.mcp.json` 的 `command` |
| `API Error: invalid api key` | key 与 host 区域不匹配 | 国内 key + `api.minimaxi.com`；海外 key + `api.minimax.io` |
| `voice clone user forbidden, should complete real-name verification` | 国内套餐需实名 | 去 `https://platform.minimaxi.com/user-center/basic-information` 完成 |
| 几分钟前能用、现在 URL 失效了 | 默认 `RESOURCE_MODE=url` 返回的是带签名的临时 URL | 改 `RESOURCE_MODE=local` 写到磁盘，或 `curl -L` 抓下来 |
| 沙盒里推送 22 端口报错 | 网络代理拦截了 SSH 22 端口 | 改用 HTTPS + token 推送 |

**安全提醒**：永远不要把 `MINIMAX_API_KEY` 写进 git 跟踪的文件（包括
`.mcp.json`）。本插件设计是宿主进程 env 解析，**不要**直接把字面值粘进
`.mcp.json`，git 检查或 debug 时容易泄。

---

## 常见问题

**Q：它到底是 MCP 还是 Skill？**
A：本仓库本质是 **MCP 插件**，里面**自带一个 Skill**（让模型知道"什么时
候用、怎么用"）。MCP 负责跟 host 通信，Skill 负责告诉模型。这是两件不
同的事，不必二选一。

**Q：能否和官方 `MiniMax-AI/MiniMax-MCP` 共存？**
A：本插件本来就只是把官方 MCP 服务器包了一层轻量的元数据。升级时只
要 `uvx minimax-mcp` 是最新版，无需改本仓库。

**Q：可以发布到 Claude/Antigravity 的 marketplace 吗？**
A：仓库根目录已经有 `.claude-plugin/marketplace.json`；提交 PR 到社区
marketplace 时沿用这个文件结构即可。

---

## 许可证

MIT——与上游 `MiniMax-AI/MiniMax-MCP` 一致。详见 `LICENSE`。
