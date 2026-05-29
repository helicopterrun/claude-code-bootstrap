# claude-code-machine-setup

Turn a fresh Linux box (VM, LXC container, server) into a comfortable
[Claude Code](https://claude.com/claude-code) working environment in one go:

- 🔑 **SSH key login via 1Password** — key lives in the 1Password SSH agent, unlocked by Touch ID / your vault, never on disk.
- 🪟 **tmux + an interactive login session picker** — every SSH login lands on a menu: attach an existing session, jump straight into a project, start a new named session, or drop to a plain shell.
- 🖱 **tmux copy / scrollback / history tuning** — mouse selection + wheel scrollback, 50k-line history.
- 📊 **A custom Claude Code statusline** — directory, git repo + branch, model, effort, a context-usage bar, and color-coded rate-limit meters with reset countdowns, plus an italic hint line of handy commands.

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

The installer is interactive and conservative: it shows what it changes, skips
anything already done, asks before installing packages, and **never disables SSH
password auth for you** (do that yourself once key login is confirmed). It will:

1. Install prerequisites (`tmux`, `jq`, `git`) with your package manager.
2. Optionally add a public key to `~/.ssh/authorized_keys` (and print the laptop-side 1Password steps).
3. Write `~/.tmux-login.sh` with the projects you enter, and wire the guarded hook into `~/.profile`.
4. Install `~/.tmux.conf` (or merge in the mouse + history settings).
5. Install `~/.claude/statusline.sh` and register it in `~/.claude/settings.json`.

> **Test from a second SSH session.** Because this touches the login path, open a
> new terminal and confirm everything works **while keeping your current session
> open** as a safety net.

## Prefer to let Claude do it?

`prompts/machine-setup.md` is the same setup written as a prompt you paste into
**Claude Code running on the new machine**. It walks through each part
interactively, asks before risky actions, and is handy when a machine's quirks
need judgment the installer doesn't have.

## What goes where

| File | Installed to | What it is |
|------|--------------|------------|
| `scripts/tmux-login.sh`    | `~/.tmux-login.sh`         | The login session picker (POSIX sh, sourced from your profile). |
| `scripts/profile-snippet.sh` | appended to `~/.profile` | Guarded hook that sources the picker on interactive SSH logins. |
| `scripts/tmux.conf`        | `~/.tmux.conf`            | Mouse, 50k scrollback, copy-mode notes. |
| `scripts/statusline.sh`    | `~/.claude/statusline.sh` | The Claude Code statusline (bash). |
| `setup.sh`                 | —                         | Interactive installer that wires it all up. |
| `prompts/machine-setup.md` | —                         | The "let Claude set it up" prompt. |

## Customizing

- **Add a tmux project:** edit the `projects="…"` block in `~/.tmux-login.sh` —
  one `key name directory` line per project. `name` is the tmux session name
  (no `.` or `:`); `directory` is where it starts.
- **Statusline colors / thresholds:** the ANSI block and `pct_color()` near the
  top of `~/.claude/statusline.sh`. It auto-folds (drops the context bar + hint
  line) under 80 columns.
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
