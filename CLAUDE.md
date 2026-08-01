# CLAUDE.md

Guidance for Claude Code (and humans) working in this repo.

## What this repo is

A small collection of shell scripts + an installer that set up a standard Claude
Code and/or Codex working environment on a fresh Linux machine: a tmux login
session picker, agent status information, tmux copy/scrollback config, and
1Password-backed SSH key login. No build system.

## Layout

- `scripts/` — the canonical files that get installed to `$HOME`. **Edit these**,
  not copies. `setup.sh` installs from here, so there is one source of truth.
- `setup.sh` — interactive installer. Reads from `scripts/`; does not embed copies.
- `prompts/machine-setup.md` — the setup written as a Claude Code prompt. It
  **does** embed the script bodies (so it's self-contained when pasted into a
  fresh machine). If you change a script in `scripts/`, update the embedded copy
  in this prompt to match.
- `AGENTS.md` — the equivalent repository guidance Codex loads automatically.
- `prompts/codex-machine-setup.md` — a Codex-native setup prompt.

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

Run `./tests/test.sh` for the complete regression check.

# Agent & Model Routing

## Hard rules
- Before any task requiring >3 tool calls, state the plan and the
  intended agent/model split. Wait for approval.
- Subagents return summaries, never file contents. Cap ~500 words.
- Never delegate to opus/fable a task with a clear spec. Clear spec = sonnet.
- Never modify the SSH login path (`profile-snippet.sh`, `tmux-login.sh`
  sourcing) without flagging it first. A bug there locks people out.

## haiku subagents
- Symbol/file location: "where is the statusline width logic"
- Grep sweeps: find all bashisms in a POSIX-sh file, all uses of a var,
  every place a script is referenced by `setup.sh` or the prompts
- Checking whether a function/guard/flag already exists in a script
- Triaging test or installer output down to the relevant 10 lines

## sonnet subagents (default worker)
- Single-script edits against a written spec
- Adding/updating cases in `tests/test.sh`
- Mechanical passes: quoting fixes, `shellcheck` cleanups, renames
- Keeping `prompts/machine-setup.md` embedded copies in sync with
  `scripts/` after an approved change
- Running the syntax checks and `./tests/test.sh` and reporting ONLY
  failures (never paste full test output into context)
- README / docs updates that mirror an already-made code change

## opus / fable (main thread, not delegated)
- Anything in the SSH login path: `profile-snippet.sh` guards,
  `tmux-login.sh` sourcing semantics, the `infocmp` check. This is
  where "it runs" ≠ "it's safe" — reason it through, then test from
  a second SSH session.
- POSIX-sh vs bash portability reasoning (dash quirks, `return` vs
  `exit` in sourced scripts)
- Installer idempotency design — what happens on re-run, on a
  half-configured machine, on a machine with existing tmux config
- Debugging with unknown cause: stranded logins, terminal/TERM
  weirdness, statusline rendering only breaking on some terminals
- Changes to the setup flow's structure or safety model

## Codex handoffs
Codex has no access to this session's context. The handoff file must
stand alone — assume it knows nothing about prior decisions.

Hand off when the task has a machine-checkable success condition:
- Bulk mechanical conversion once I've approved the pattern on one file
  (quoting fixes, `local` removal for POSIX sh, shellcheck cleanup)
- Boilerplate: new test cases against `tests/test.sh`'s existing shape
- Fix loops where `sh -n` / `bash -n` / `./tests/test.sh` output IS
  the spec
- Syncing embedded script bodies in `prompts/*.md` after the canonical
  `scripts/` version is final
- Docs churn following an already-merged change

Do NOT hand off:
- Anything in the SSH login path — "the test passed" ≠ "nobody gets
  locked out", and Codex will happily delete the `infocmp` guard to
  simplify the code
- Installer idempotency or safety behavior
- POSIX-compliance judgment calls (it will introduce bashisms into
  `tmux-login.sh` to make something work)
- Anything where acceptance is subjective (menu UX, statusline layout)
- Work on files I haven't reviewed the current state of

Handoff file: `handoff/<task>.md` containing
1. Goal, one sentence
2. Exact file list in scope — Codex touches nothing outside it
3. A worked example of the pattern (before/after) if mechanical
4. Acceptance: the exact command that must pass
   (e.g. `sh -n scripts/tmux-login.sh && bash -n scripts/statusline.sh && ./tests/test.sh`)
5. Explicit DO-NOT-TOUCH list: `profile-snippet.sh`, the sourcing/
   `return` semantics of `tmux-login.sh`, the `infocmp` guard,
   anything that disables SSH password auth
6. Forbidden escapes: no bashisms in POSIX-sh files, no `exit` in
   sourced code paths, no deleting guards or tests to make checks pass

Then stop and tell me the file is ready. Do not continue working
on that scope while Codex has it.

## Shell-specific context hygiene
- Test failures: report the first 3 distinct failures, not the cascade.
- Never paste full installer or tmux session output verbatim — summarize.
- When a session exceeds ~2 hours of work, write `handoff/state.md`
  and tell me to start fresh rather than compacting.

## Session pacing
- At session start, ask what the scope is and estimate whether it fits
  in one usage window. If not, propose splitting before starting.
- Prefer a fresh session with a 10-line handoff note over turn 40 of
  a session carrying full logs and file dumps.
