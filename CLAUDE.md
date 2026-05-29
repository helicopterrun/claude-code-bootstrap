# CLAUDE.md

Guidance for Claude Code (and humans) working in this repo.

## What this repo is

A small collection of shell scripts + an installer that set up a standard Claude
Code working environment on a fresh Linux machine: a tmux login session picker, a
custom Claude Code statusline, tmux copy/scrollback config, and 1Password-backed
SSH key login. No build system, no dependencies beyond `tmux`, `jq`, `git`.

## Layout

- `scripts/` — the canonical files that get installed to `$HOME`. **Edit these**,
  not copies. `setup.sh` installs from here, so there is one source of truth.
- `setup.sh` — interactive installer. Reads from `scripts/`; does not embed copies.
- `prompts/machine-setup.md` — the setup written as a Claude Code prompt. It
  **does** embed the script bodies (so it's self-contained when pasted into a
  fresh machine). If you change a script in `scripts/`, update the embedded copy
  in this prompt to match.

## Conventions

- `scripts/tmux-login.sh` is **POSIX sh** (it's sourced by `~/.profile`, which may
  be `dash`). No bashisms. Verify with `sh -n`. It is meant to be **sourced**, so
  the no-tmux paths use `return`, not `exit`.
- `scripts/statusline.sh` is **bash** (uses arrays, `mapfile`, `${var//}`).
  Verify with `bash -n`. It must always `exit 0` and tolerate empty/garbage stdin.
- The statusline reads all JSON fields in **one** `jq` call (perf: it runs on
  every render). Keep it that way — don't reintroduce per-field `jq` calls.
- Keep edits small and readable; match the surrounding comment density.

## Safety (important)

These scripts run in the SSH login path. A bug can lock someone out of a machine.

- After changing the login flow, **test from a second SSH session** while keeping
  the current one open.
- The installer must stay **idempotent** (safe to re-run) and must **never** disable
  SSH password auth automatically — that's left to the user, on purpose.
- Preserve the guards in `profile-snippet.sh` (interactive + SSH + tmux present +
  resolvable `$TERM` via `infocmp`). The `infocmp` check is what prevents an
  unknown terminal from exec'ing a tmux that instantly dies and strands the login.

## Testing

```bash
# Syntax
sh   -n scripts/tmux-login.sh
bash -n scripts/statusline.sh
bash -n setup.sh

# Statusline render (wide / narrow / missing fields)
echo '{"workspace":{"current_dir":"'"$HOME"'/p","repo":{"name":"p"}},"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":42}}' \
  | COLUMNS=200 bash scripts/statusline.sh
printf '%s' 'not json' | bash scripts/statusline.sh   # must still exit 0

# Picker menu render (the 's' choice draws once then exits cleanly when not sourced)
printf 's\n' | sh scripts/tmux-login.sh
```

When changing the statusline's fields or layout, re-test all four cases above and
confirm exit status 0.
