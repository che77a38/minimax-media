#!/usr/bin/env bash
# Resolve an absolute path to uvx for hosts that need one (macOS Codex desktop often
# does not expose ~/.local/bin to spawned MCP processes). Falls back to PATH.
set -e
if [ -n "${MINIMAX_UVX_PATH:-}" ]; then
  echo "$MINIMAX_UVX_PATH"; exit 0
fi
if command -v uvx >/dev/null 2>&1; then
  command -v uvx; exit 0
fi
for cand in /opt/homebrew/bin/uvx /usr/local/bin/uvx "$HOME/.local/bin/uvx" "$HOME/.cargo/bin/uvx"; do
  [ -x "$cand" ] && { echo "$cand"; exit 0; }
done
echo "uvx not found; install Astral's uv (https://docs.astral.sh/uv/)" >&2
exit 127
