# Set up this Linux machine for Codex

Help me turn this Linux machine into a comfortable Codex CLI environment.
Clone this repository if it is not already present, inspect the current machine
without overwriting existing configuration, and run:

```bash
./setup.sh --codex
```

Work interactively and preserve these rules:

- Never disable SSH password authentication.
- Before changing the SSH login path, show what will change.
- Keep the current SSH connection open and test from a second connection.
- Preserve existing tmux and Codex configuration.
- If Codex is absent, offer the official installer and ask before running it.
- After setup, run `codex doctor`, verify `codex --version`, and start Codex in
  a project directory. Use `/status` to inspect the session and `/model` to
  select a model and reasoning effort.
- Confirm that Codex loads the repository's `AGENTS.md`.

The installer configures Codex's native footer with directory, Git branch,
model/reasoning, and context remaining. Do not install the Claude Code
statusline for a Codex-only setup.
