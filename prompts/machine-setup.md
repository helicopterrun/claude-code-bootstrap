# Setup prompt — "make this machine feel like home"

Paste everything below the line into **Claude Code running on the new Linux machine**
(an LXC container, VM, fresh server, etc.). It walks you through four things:

1. **SSH key login backed by 1Password** (no more passwords)
2. **tmux** + an interactive **login session picker** (attach existing / start a project / new / plain shell)
3. **A custom Claude Code statusline** (dir, git, model, effort, context bar, rate limits, hint line)

It's written so Claude does the server-side work for you, asks before anything risky,
and never locks you out of SSH. The 1Password steps that happen on *your laptop* are
spelled out for you to do by hand (Claude can't reach your laptop).

---

You are helping me turn a freshly provisioned Linux machine into my standard Claude Code
working environment. Work through the parts below **in order**, one at a time. After each
part, show me what you did and confirm it works before moving on.

## Ground rules (important — follow these)

- **Never lock me out of SSH.** I am connected to this machine right now. Before changing
  anything in the SSH login path (`~/.profile`, `sshd_config`, `authorized_keys`), tell me
  what you're about to change. After changes to the login flow, have me **open a second SSH
  connection in a new terminal to test**, while keeping my current session open as a safety net.
- **Ask before destructive or hard-to-reverse actions** (disabling password auth, restarting
  sshd, overwriting an existing file). Show the current contents of any file before replacing it.
- Detect my OS and package manager first (`apt`, `dnf`, `pacman`, `apk`, …) and use the right one.
- This is my own machine / authorized container — standard system administration is fine.
- If something is already set up correctly, say so and skip it rather than redoing it.

## Part 0 — Prerequisites

1. Tell me the OS (`cat /etc/os-release`), the shell, and whether this is an LXC container.
2. Install the tools the rest of this needs, using my package manager: **`tmux`**, **`jq`**,
   **`git`**. Confirm versions afterward (`tmux -V`, `jq --version`, `git --version`).
3. Confirm Claude Code's config dir exists: `~/.claude/` (create it if missing).

## Part 1 — SSH key login with 1Password

Goal: I log in with an SSH key stored in 1Password's SSH agent, so the private key never
lives on disk and is unlocked by Touch ID / my 1Password password.

**These steps are on MY laptop (the client) — print them for me to do, then wait:**

1. Install the 1Password 8 desktop app and the browser extension if I don't have them.
2. In 1Password: **Settings → Developer → "Use the SSH agent"** → enable it.
   (Optionally enable "Display key names" / the on-screen prompt.)
3. Create a new SSH key item in 1Password (**New Item → SSH Key**), or import an existing one.
   1Password generates an Ed25519 key by default — good.
4. Tell my local SSH client to use the 1Password agent. On macOS the agent socket is
   `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`; on Linux it's
   `~/.1password/agent.sock`. Add to my laptop's `~/.ssh/config`:
   ```
   Host *
       IdentityAgent ~/.1password/agent.sock   # macOS: the Group Containers path above
   ```
5. Copy my **public** key from the 1Password key item (the `ssh-ed25519 AAAA…` string).

**Then, here on the server, do this for me:**

6. Ask me to paste my public key. Append it to `~/.ssh/authorized_keys` (create `~/.ssh`
   with `700` and `authorized_keys` with `600` if needed; don't clobber existing keys —
   append, and skip if the exact key is already present).
7. Verify `sshd` allows public-key auth: check `PubkeyAuthentication` (default yes). Report
   the effective config with `sshd -T | grep -i pubkey` if available.
8. Have me **open a new terminal and test key login** before anything else changes.
9. **Only if I explicitly confirm** the key works and I ask for it: optionally harden by
   setting `PasswordAuthentication no` (and `KbdInteractiveAuthentication no`) in a drop-in
   under `/etc/ssh/sshd_config.d/`, then `sshd -t` to validate and restart sshd. Warn me
   clearly that this disables password login. Default to **leaving password auth on** unless I ask.

## Part 2 — tmux + login session picker

Goal: SSH logins land on an interactive menu to attach an existing tmux session, start one
of my project sessions, create a new named session, or drop to a plain shell.

1. **Ask me for my project list.** Each project is one line of `key name directory`, where
   `key` is the menu letter, `name` is the tmux session name (no `.` or `:`), and `directory`
   is where that session starts. Example to show me (mine looks like this — yours will differ):
   ```
   h home-assistant /root/home-assistant
   a agent /root/agent
   e esphome /root/esphome
   r root /root
   ```
   Create any of those directories that don't exist (ask first).

2. **Write `~/.tmux-login.sh`** with exactly the content below, but replace the `projects="…"`
   block with my project list from step 1:

   ```sh
   # ~/.tmux-login.sh — interactive tmux session picker for SSH logins.
   #
   # Sourced from ~/.profile AFTER its SSH / interactive / $TERM guards pass.
   # Meant to be sourced, not executed: it uses `return` (not `exit`) for the
   # no-tmux paths so the user lands in a normal login shell. The attach/new
   # paths `exec tmux ...`, replacing the login shell, so quitting tmux logs out.
   #
   # To add a project: add one "key name dir" line to $projects below.

   # key  session-name      start-directory
   projects="h home-assistant /root/home-assistant
   a agent /root/agent
   e esphome /root/esphome
   r root /root"

   # Default action: attach the most-recently-used session, else create 'claude'.
   _tmux_login_default() {
   	if [ -n "$(tmux list-sessions 2>/dev/null)" ]; then
   		exec tmux attach
   	else
   		exec tmux new-session -A -s claude -c "$HOME"
   	fi
   }

   # Sanitize a free-form session name: tmux forbids '.' and ':'; collapse those
   # and whitespace to '_'.
   _tmux_login_sanitize() {
   	printf '%s' "$1" | tr ' \t.:' '____'
   }

   while :; do
   	# Snapshot existing sessions (name<TAB>path), numbered 1..N.
   	sessions="$(tmux list-sessions -F '#{session_name}	#{session_path}' 2>/dev/null)"

   	echo ""
   	echo "Existing sessions:"
   	if [ -n "$sessions" ]; then
   		i=0
   		printf '%s\n' "$sessions" | while IFS='	' read -r sname spath; do
   			i=$((i + 1))
   			printf '  %d) %-12s (%s)\n' "$i" "$sname" "$spath"
   		done
   	else
   		echo "  (none)"
   	fi

   	echo ""
   	echo "Projects:"
   	printf '%s\n' "$projects" | while read -r pkey pname pdir; do
   		if tmux has-session -t "$pname" 2>/dev/null; then
   			printf '  %s) %-14s [running]\n' "$pkey" "$pname"
   		else
   			printf '  %s) %s\n' "$pkey" "$pname"
   		fi
   	done

   	echo ""
   	echo "[n] new named  [s] shell  [q] quit"
   	echo "  (inside tmux: Ctrl+b → d = leave tmux session | Ctrl+b → s = switch tmux session)"
   	printf 'Choice: '

   	# Empty input / EOF / closed connection -> default action (never spin).
   	if ! read -r choice; then
   		_tmux_login_default
   	fi
   	[ -z "$choice" ] && _tmux_login_default

   	case "$choice" in
   		s | q)
   			# Drop into a normal, non-tmux login shell.
   			return 0 2>/dev/null || break
   			;;
   		n)
   			printf 'New session name: '
   			read -r newname || continue
   			[ -z "$newname" ] && continue
   			newname="$(_tmux_login_sanitize "$newname")"
   			printf 'Start directory [%s]: ' "$HOME"
   			read -r newdir || newdir=""
   			[ -z "$newdir" ] && newdir="$HOME"
   			if tmux has-session -t "$newname" 2>/dev/null; then
   				exec tmux attach -t "$newname"
   			else
   				exec tmux new-session -s "$newname" -c "$newdir"
   			fi
   			;;
   		[0-9] | [0-9][0-9])
   			# Attach the Nth existing session.
   			sname="$(printf '%s\n' "$sessions" | sed -n "${choice}p" | cut -f1)"
   			if [ -n "$sname" ]; then
   				exec tmux attach -t "$sname"
   			fi
   			echo "No session #$choice." >&2
   			;;
   		*)
   			# Maybe a project key.
   			match="$(printf '%s\n' "$projects" | while read -r pkey pname pdir; do
   				[ "$pkey" = "$choice" ] && printf '%s\t%s\n' "$pname" "$pdir"
   			done)"
   			if [ -n "$match" ]; then
   				pname="$(printf '%s' "$match" | cut -f1)"
   				pdir="$(printf '%s' "$match" | cut -f2)"
   				if tmux has-session -t "$pname" 2>/dev/null; then
   					exec tmux attach -t "$pname"
   				else
   					exec tmux new-session -s "$pname" -c "$pdir"
   				fi
   			fi
   			echo "Unrecognized choice: $choice" >&2
   			;;
   	esac
   	# Fell through (invalid input) -> redraw the menu.
   done
   ```

3. **Wire it into `~/.profile`.** Append this block (show me `~/.profile` first; if a tmux
   auto-attach block already exists, replace it). The guards matter: they keep the picker from
   firing on non-interactive/non-SSH shells, and the `infocmp` check prevents an unknown
   `$TERM` from exec'ing a tmux that instantly dies and strands the login.
   ```sh
   # Interactive tmux session picker on SSH/mosh login.
   if [ -z "$TMUX" ] \
      && [ -n "$PS1" ] \
      && { [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; } \
      && command -v tmux >/dev/null 2>&1; then
     if infocmp "$TERM" >/dev/null 2>&1; then
       . "$HOME/.tmux-login.sh"
     else
       echo "warning: TERM=$TERM not in terminfo db; skipping tmux picker" >&2
       echo "  install it from your client: infocmp -x \$TERM | ssh <user>@<host> -- tic -x -" >&2
     fi
   fi
   ```
   Note: some distros only source `~/.profile` for login shells via `~/.bash_profile`. If
   `~/.bash_profile` exists and doesn't source `~/.profile`, point this at the right file for
   my shell (or add a `. ~/.profile` to `~/.bash_profile`).

4. **Verify safely:** `sh -n ~/.tmux-login.sh` for syntax, then have me open a **second** SSH
   session to see the menu and exercise each path (pick a project, detach with `Ctrl+b` then
   `d`, reattach by number, `n` for a new one, `s` for a plain shell). Keep my current session
   open the whole time.

## Part 2b — tmux copy / scrollback / history config

Goal: mouse selection + wheel scrollback and a generous history buffer.

1. **Write `~/.tmux.conf`** with this content (if it already exists, don't clobber
   it — just append any of these settings that are missing):
   ```
   # ~/.tmux.conf — terminal copy / scrollback / history behavior.

   # Mouse: wheel scrolls into copy-mode history; drag selects; click picks panes.
   set -g mouse on

   # Scrollback buffer size (lines per pane). Default 2000; 50k is roomy.
   set -g history-limit 50000

   # With `mouse on`, drag selects into tmux's buffer, not the terminal's. To use
   # your terminal's native copy (e.g. across panes), hold SHIFT while dragging.
   # Optional (uncomment to taste):
   #   setw -g mode-keys vi
   #   set -g set-clipboard on
   ```
2. If I'm in a running tmux, reload it: `tmux source-file ~/.tmux.conf`.

## Part 3 — Custom Claude Code statusline

Goal: a two-line statusline — status on top (dir, repo, branch, model, effort, a context
progress bar, and 1Password-style rate-limit meters), and an italic hint line below. It folds
gracefully on narrow/mobile widths and reads everything from one fast `jq` call. Needs `jq`
and `git` (installed in Part 0).

1. **Write `~/.claude/statusline.sh`** with exactly this content, then `chmod +x` it:

   ```bash
   #!/usr/bin/env bash
   # Claude Code statusline — reads JSON on stdin, prints colored status to stdout.
   #
   # Line 1 (status): location/git │ session state │ rate limits
   # Line 2 (hint):   Claude commands + tmux shortcuts (desktop only)
   # When space is constrained (<80 cols) the context bar and hint line are dropped.

   set -u

   input="$(cat)"
   now="$(date +%s)"

   # ANSI
   CYAN=$'\033[36m'
   GREEN=$'\033[32m'
   MAGENTA=$'\033[35m'
   YELLOW=$'\033[33m'
   RED=$'\033[31m'
   BLUE=$'\033[34m'
   DIM=$'\033[2m'
   ITALIC=$'\033[3m'
   RESET=$'\033[0m'

   # One jq pass extracts every field (empty string when missing/null), in order.
   mapfile -t F < <(jq -r '
       [ (.workspace.current_dir // .cwd // ""),
         (.model.display_name // ""),
         (.effort.level // ""),
         (.context_window.used_percentage // ""),
         (.workspace.repo.name // ""),
         (.workspace.git_worktree // ""),
         (.rate_limits.five_hour.used_percentage // ""),
         (.rate_limits.five_hour.resets_at // ""),
         (.rate_limits.seven_day.used_percentage // ""),
         (.rate_limits.seven_day.resets_at // "")
       ] | .[]' <<<"$input" 2>/dev/null)

   cwd="${F[0]:-}"
   model="${F[1]:-}"
   effort="${F[2]:-}"
   ctx_raw="${F[3]:-}"
   repo_name="${F[4]:-}"
   worktree="${F[5]:-}"
   rl5_pct="${F[6]:-}"
   rl5_reset="${F[7]:-}"
   rl7_pct="${F[8]:-}"
   rl7_reset="${F[9]:-}"

   # Collapse $HOME to ~
   if [[ -n "$cwd" && -n "${HOME:-}" && "$cwd" == "$HOME"* ]]; then
       cwd="~${cwd#$HOME}"
   fi

   # Git branch if cwd is in a repo
   branch=""
   if [[ -n "$cwd" ]]; then
       real_cwd="${cwd/#\~/$HOME}"
       if [[ -d "$real_cwd" ]]; then
           branch="$(git -C "$real_cwd" symbolic-ref --short HEAD 2>/dev/null \
               || git -C "$real_cwd" rev-parse --short HEAD 2>/dev/null \
               || true)"
       fi
   fi

   # Color by percentage: green < 50 <= yellow < 80 <= red
   pct_color() {
       if   (( $1 >= 80 )); then printf '%s' "$RED"
       elif (( $1 >= 50 )); then printf '%s' "$YELLOW"
       else                      printf '%s' "$GREEN"
       fi
   }

   # Compact "time until" string for an epoch-seconds reset target (uses global $now).
   fmt_reset() {
       local diff d h m
       diff=$(( $1 - now ))
       (( diff < 0 )) && diff=0
       d=$(( diff / 86400 ))
       h=$(( (diff % 86400) / 3600 ))
       m=$(( (diff % 3600) / 60 ))
       if   (( d > 0 )); then printf '%dd%dh' "$d" "$h"
       elif (( h > 0 )); then printf '%dh%dm' "$h" "$m"
       else                   printf '%dm' "$m"
       fi
   }

   # Build one rate-limit segment: "5h : 34% ↻2h13m" (↻ = resets-in)
   rl_segment() {
       local label="$1" pctv="$2" resetv="$3" p seg
       [[ -z "$pctv" || "$pctv" == "null" ]] && return 0
       p="$(printf '%.0f' "$pctv" 2>/dev/null || echo 0)"
       seg="$(pct_color "$p")${label} : ${p}%${RESET}"
       if [[ -n "$resetv" && "$resetv" != "null" ]]; then
           seg="${seg} ${DIM}↻$(fmt_reset "$resetv")${RESET}"
       fi
       printf '%s' "$seg"
   }

   # Join args with a separator, dropping nothing (caller pre-filters empties).
   join_with() {
       local sepv="$1"; shift
       [[ $# -eq 0 ]] && return 0
       local IFS=$'\x1f'
       local joined="$*"
       printf '%s' "${joined//$'\x1f'/$sepv}"
   }

   # Width detection. Claude Code sets COLUMNS (v2.1.153+); fall back to tmux, then tput.
   cols="${COLUMNS:-}"
   if [[ -z "$cols" && -n "${TMUX:-}" ]]; then
       cols="$(tmux display -p '#{window_width}' 2>/dev/null || true)"
   fi
   [[ -z "$cols" ]] && cols="$(tput cols 2>/dev/null || true)"
   [[ -z "$cols" ]] && cols=999
   narrow=0
   (( cols < 80 )) && narrow=1

   # Context: "ctx: [████░░░░░░] 42%" on desktop, bare "ctx: 42%" on phone (the
   # bar costs ~13 cols we don't have on narrow screens, but the % is worth keeping).
   ctx_segment=""
   if [[ -n "$ctx_raw" && "$ctx_raw" != "null" ]]; then
       pct="$(printf '%.0f' "$ctx_raw" 2>/dev/null || echo 0)"
       (( pct < 0 )) && pct=0
       (( pct > 100 )) && pct=100
       if (( narrow )); then
           ctx_segment="${DIM}ctx:${RESET} $(pct_color "$pct")${pct}%${RESET}"
       else
           filled=$(( (pct + 5) / 10 ))
           (( filled < 0 )) && filled=0
           (( filled > 10 )) && filled=10
           empty=$(( 10 - filled ))
           bar=""
           for ((i=0; i<filled; i++)); do bar+="█"; done
           for ((i=0; i<empty;  i++)); do bar+="░"; done
           ctx_segment="${DIM}ctx:${RESET} [$(pct_color "$pct")${bar}${RESET}] ${pct}%"
       fi
   fi

   # --- Group A: location + git ---
   gA_parts=()
   [[ -n "$cwd"       ]] && gA_parts+=("${CYAN}${cwd}${RESET}")
   [[ -n "$repo_name" ]] && gA_parts+=("${BLUE}${repo_name}${RESET}")
   [[ -n "$branch"    ]] && gA_parts+=("${GREEN}${branch}${RESET}")
   [[ -n "$worktree"  ]] && gA_parts+=("${DIM}wt:${worktree}${RESET}")

   # --- Group B: session state ---
   gB_parts=()
   [[ -n "$model"  ]] && gB_parts+=("${MAGENTA}${model}${RESET}")
   [[ -n "$effort" ]] && gB_parts+=("${DIM}effort:${RESET} ${YELLOW}${effort}${RESET}")
   [[ -n "$ctx_segment" ]] && gB_parts+=("$ctx_segment")

   # --- Group C: rate limits ("lmt: 5h : 34% ↻2h13m · 7d : 12% ↻5d3h") ---
   rl_parts=()
   seg="$(rl_segment "5h" "$rl5_pct" "$rl5_reset")"; [[ -n "$seg" ]] && rl_parts+=("$seg")
   seg="$(rl_segment "7d" "$rl7_pct" "$rl7_reset")"; [[ -n "$seg" ]] && rl_parts+=("$seg")
   gC=""
   if (( ${#rl_parts[@]} > 0 )); then
       gC="${DIM}lmt:${RESET} $(join_with " · " "${rl_parts[@]}")"
   fi

   gA="$(join_with "  " "${gA_parts[@]+"${gA_parts[@]}"}")"
   gB="$(join_with "  " "${gB_parts[@]+"${gB_parts[@]}"}")"

   if (( narrow )); then
       # Phone / narrow terminal: trade horizontal for vertical space. Each group
       # gets its own line so nothing is pushed off the right edge and truncated.
       # The two rate limits fit comfortably together, so they share one line.
       [[ -n "$gA" ]] && printf '%b\n' "$gA"
       [[ -n "$gB" ]] && printf '%b\n' "$gB"
       [[ -n "$gC" ]] && printf '%b\n' "$gC"
       exit 0
   fi

   # Wide terminal: single status line (groups joined by a dim separator) + hint.
   groups=()
   [[ -n "$gA" ]] && groups+=("$gA")
   [[ -n "$gB" ]] && groups+=("$gB")
   [[ -n "$gC" ]] && groups+=("$gC")
   status="$(join_with " ${DIM}│${RESET} " "${groups[@]+"${groups[@]}"}")"

   hint="hint: /model · /effort · /exit · ! <cmd> = run terminal command"
   if [[ -n "${TMUX:-}" ]]; then
       hint="${hint} · Ctrl+b → d:leave tmux session · Ctrl+b → s:switch tmux session"
   fi
   shortcuts="${DIM}${ITALIC}${hint}${RESET}"

   [[ -n "$status"    ]] && printf '%b\n' "$status"
   [[ -n "$shortcuts" ]] && printf '%b\n' "$shortcuts"
   exit 0
   ```

2. **Register it** in `~/.claude/settings.json` (merge into existing JSON; don't drop my other
   settings). Add:
   ```json
   {
     "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }
   }
   ```

3. **Verify** by piping sample JSON through it and checking it renders without errors and
   exits 0 — test a wide width, a narrow width (`COLUMNS=60`), and missing fields. Example:
   ```bash
   bash -n ~/.claude/statusline.sh
   echo '{"workspace":{"current_dir":"'"$HOME"'/proj","repo":{"name":"proj"}},"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":9999999999},"seven_day":{"used_percentage":5,"resets_at":9999999999}}}' \
     | COLUMNS=200 bash ~/.claude/statusline.sh
   ```
   Then tell me to look at the bottom of Claude Code — it refreshes on its own.

   Notes: rate-limit meters only appear for Claude.ai Pro/Max accounts after the first API
   response in a session (they're absent otherwise — that's expected). Italic on the hint line
   depends on terminal support.

## Wrap up

When all parts are done, give me a short recap: what was installed, what files were created
or changed (`~/.ssh/authorized_keys`, `~/.profile`, `~/.tmux-login.sh`, `~/.tmux.conf`,
`~/.claude/statusline.sh`, `~/.claude/settings.json`), and any follow-ups (e.g. "test key login from a fresh terminal",
"add more projects by editing the `projects=` block in `~/.tmux-login.sh`").
