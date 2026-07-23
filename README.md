# coding-agent-machine-setup

Turn a fresh Linux box (VM, LXC container, server) into a comfortable
[Codex](https://developers.openai.com/codex/) and/or
[Claude Code](https://claude.com/claude-code) working environment in one go:

- 🔑 **SSH key login via 1Password** — key lives in the 1Password SSH agent, unlocked by Touch ID / your vault, never on disk.
- 🪟 **tmux + an interactive login session picker** — every SSH login lands on a menu: attach an existing session, jump straight into a project, start a new named session, or drop to a plain shell.
- 🖱 **tmux copy / scrollback / history tuning** — mouse selection + wheel scrollback, 50k-line history.
- 📊 **Agent-native status information** — Codex gets a native footer with directory, Git branch, model/reasoning, and context remaining; Claude Code keeps the custom two-line statusline with rate-limit meters.
- 🧭 **Native instruction files** — `AGENTS.md` for Codex and `CLAUDE.md` for Claude Code carry equivalent repository guidance.

It's all small, readable shell — no frameworks, no daemons.

```
~/esphome  esphome-configs  main │ Opus 4.8  effort: high  ctx: [████░░░░░░] 42% │ lmt: 5h : 6% ↻2h40m · 7d : 1% ↻1d9h
hint: /model · /effort · /exit · ! <cmd> = run terminal command · Ctrl+b → d:leave tmux session · Ctrl+b → s:switch tmux session
```

```
Existing sessions:
  1) claude     (~)
  2) esphome    (~/esphome)

Projects:
  h) home-assistant
  a) agent
  e) esphome      [running]
  r) root

[n] new named  [s] shell  [q] quit
  (inside tmux: Ctrl+b → d = leave tmux session | Ctrl+b → s = switch tmux session)
Choice:
```

## Quick start

```bash
git clone https://github.com/helicopterrun/claude-code-bootstrap.git
cd claude-code-bootstrap
./setup.sh
```

Choose a specific agent when desired:

```bash
./setup.sh --codex
./setup.sh --claude
./setup.sh --both
```

With no flag, the installer detects installed agents; if neither is present it
defaults to Codex setup.

The installer is interactive and conservative: it shows what it changes, skips
anything already done, asks before installing packages, and **never disables SSH
password auth for you** (do that yourself once key login is confirmed). It will:

1. Install prerequisites (`tmux`, `jq`, `git`) with your package manager.
2. Optionally add a public key to `~/.ssh/authorized_keys` (and print the laptop-side 1Password steps).
3. Write `~/.tmux-login.sh` with the projects you enter, and wire the guarded hook into `~/.profile`.
4. Install `~/.tmux.conf` (or merge in the mouse + history settings).
5. Configure Codex's native footer in `~/.codex/config.toml`, install Claude's
   custom statusline, or both, according to the selected mode.

> **Test from a second SSH session.** Because this touches the login path, open a
> new terminal and confirm everything works **while keeping your current session
> open** as a safety net.

## Prefer to let an agent do it?

`prompts/machine-setup.md` is the same setup written as a prompt you paste into
**Claude Code running on the new machine**. It walks through each part
interactively, asks before risky actions, and is handy when a machine's quirks
need judgment the installer doesn't have.

For Codex, use `prompts/codex-machine-setup.md`. Codex also reads this
repository's `AGENTS.md` automatically.

## What goes where

| File | Installed to | What it is |
|------|--------------|------------|
| `scripts/tmux-login.sh`    | `~/.tmux-login.sh`         | The login session picker (POSIX sh, sourced from your profile). |
| `scripts/profile-snippet.sh` | appended to `~/.profile` | Guarded hook that sources the picker on interactive SSH logins. |
| `scripts/tmux.conf`        | `~/.tmux.conf`            | Mouse, 50k scrollback, copy-mode notes. |
| `scripts/statusline.sh`    | `~/.claude/statusline.sh` | The Claude Code statusline (bash). |
| native Codex configuration | `~/.codex/config.toml` | Codex footer; no wrapper script required. |
| `setup.sh`                 | —                         | Interactive installer that wires it all up. |
| `prompts/machine-setup.md` | —                         | The "let Claude set it up" prompt. |
| `prompts/codex-machine-setup.md` | —                    | The equivalent Codex setup prompt. |

## Customizing

- **Add a tmux project:** edit the `projects="…"` block in `~/.tmux-login.sh` —
  one `key name directory` line per project. `name` is the tmux session name
  (no `.` or `:`); `directory` is where it starts.
- **Statusline colors / thresholds:** the ANSI block and `pct_color()` near the
  top of `~/.claude/statusline.sh`. It auto-folds (drops the context bar + hint
  line) under 80 columns.
- **Codex footer:** edit `tui.status_line` in `~/.codex/config.toml`. Run
  `/status` for full session configuration and `/model` to change model or
  reasoning effort.
- **tmux clipboard / vi keys:** uncomment the optional lines at the bottom of
  `~/.tmux.conf`, then `tmux source-file ~/.tmux.conf`.

## Notes & caveats

- **Rate-limit meters** appear only for Claude.ai Pro/Max accounts, and only
  after the first API response in a session — otherwise they're simply absent.
- **Italic hint line** depends on terminal support (most modern terminals are fine).
- **Profile sourcing:** some distros source `~/.bash_profile` (not `~/.profile`)
  on login; the installer detects this, but if your picker doesn't appear, make
  sure the file your shell sources pulls in the snippet.
- **Unknown `$TERM`:** the login hook skips the picker (rather than stranding you)
  if your `$TERM` isn't in the server's terminfo db, and prints how to install it.

## License

MIT — see [LICENSE](LICENSE).
