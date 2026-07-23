# AGENTS.md

Guidance for Codex (and humans) working in this repo.

## What this repo is

A small collection of shell scripts and an installer that set up a comfortable
Claude Code and/or Codex working environment on a fresh Linux machine: a tmux
login session picker, agent status information, tmux copy/scrollback config,
and 1Password-backed SSH key login. There is no build system.

## Layout

- `scripts/` contains canonical files installed into `$HOME`. Edit these, not
  installed copies.
- `setup.sh` is the interactive, idempotent installer.
- `scripts/statusline.sh` is Claude Code-specific. Codex uses its native
  `tui.status_line` setting instead.
- `prompts/machine-setup.md` is the self-contained Claude Code setup prompt.
- `prompts/codex-machine-setup.md` is the Codex setup prompt.

## Conventions

- `scripts/tmux-login.sh` is POSIX sh. Verify it with `sh -n`.
- `scripts/statusline.sh` and `setup.sh` are Bash. Verify them with `bash -n`.
- Keep `CLAUDE.md` and `AGENTS.md` aligned when shared repository guidance
  changes.
- Keep edits small, readable, and idempotent.

## Safety

These scripts run in the SSH login path. Never disable SSH password
authentication automatically. Preserve the interactive, SSH, tmux, and
terminfo guards in `scripts/profile-snippet.sh`. After login-flow changes, test
from a second SSH session while keeping the first session open.

## Testing

```bash
sh -n scripts/tmux-login.sh
bash -n scripts/statusline.sh
bash -n setup.sh
./tests/test.sh
```
