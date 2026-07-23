#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

sh -n scripts/tmux-login.sh
bash -n scripts/statusline.sh
bash -n setup.sh

printf '%s' 'not json' | bash scripts/statusline.sh >/dev/null
echo '{"workspace":{"current_dir":"/tmp","repo":{"name":"demo"}},"model":{"display_name":"test"},"context_window":{"used_percentage":42}}' \
  | COLUMNS=120 bash scripts/statusline.sh >/dev/null

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf '[tui]\nanimations = true\n' > "$tmp_dir/config.toml"
bash setup.sh --write-codex-status "$tmp_dir/config.toml"
grep -q '^status_line = \["current-dir", "git-branch", "model-with-reasoning", "context-remaining"\]$' "$tmp_dir/config.toml"

bash setup.sh --write-codex-status "$tmp_dir/config.toml"
[ "$(grep -c '^status_line = ' "$tmp_dir/config.toml")" -eq 1 ]

printf 'model = "test"\n' > "$tmp_dir/config.toml"
bash setup.sh --write-codex-status "$tmp_dir/config.toml"
grep -q '^\[tui\]$' "$tmp_dir/config.toml"

echo "all tests passed"
