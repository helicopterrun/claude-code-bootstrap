#!/usr/bin/env bash
# setup.sh — set up tmux session picker + Claude Code statusline on this machine.
#
# Usage:  git clone <repo> && cd <repo> && ./setup.sh
#
# Idempotent and conservative: it shows what it changes, skips work already done,
# and never disables SSH password auth (that's left to you, on purpose).

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/scripts"

c_bold=$'\033[1m'; c_dim=$'\033[2m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_rst=$'\033[0m'
say()  { printf '%s\n' "${c_bold}==>${c_rst} $*"; }
note() { printf '%s\n' "    ${c_dim}$*${c_rst}"; }
ok()   { printf '%s\n' "    ${c_grn}✓${c_rst} $*"; }
warn() { printf '%s\n' "    ${c_ylw}!${c_rst} $*"; }
ask()  { # ask "prompt" "default" -> echoes answer
	local q="$1" def="${2:-}" a
	if [ -n "$def" ]; then printf '%s [%s]: ' "$q" "$def" >&2; else printf '%s: ' "$q" >&2; fi
	read -r a || a=""
	[ -z "$a" ] && a="$def"
	printf '%s' "$a"
}
confirm() { # confirm "prompt" -> returns 0 if yes
	local a; a="$(ask "$1 (y/N)" "")"; case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

[ -d "$SCRIPTS" ] || { printf '%s\n' "${c_red}error:${c_rst} run this from the cloned repo (scripts/ not found next to setup.sh)"; exit 1; }

printf '\n%s\n\n' "${c_bold}Claude Code machine setup${c_rst}"
note "Files this can create/modify:"
note "  ~/.tmux-login.sh, ~/.profile, ~/.claude/statusline.sh, ~/.claude/settings.json, ~/.ssh/authorized_keys"
echo

# --- Part 0: prerequisites -------------------------------------------------
say "Checking prerequisites (tmux, jq, git)"
PKG=""
if   command -v apt-get >/dev/null 2>&1; then PKG="sudo apt-get install -y"
elif command -v dnf     >/dev/null 2>&1; then PKG="sudo dnf install -y"
elif command -v pacman  >/dev/null 2>&1; then PKG="sudo pacman -S --noconfirm"
elif command -v apk     >/dev/null 2>&1; then PKG="sudo apk add"
elif command -v zypper  >/dev/null 2>&1; then PKG="sudo zypper install -y"
fi
# Drop sudo if we're already root.
[ "$(id -u)" = "0" ] && PKG="${PKG#sudo }"

missing=""
for t in tmux jq git; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
if [ -n "$missing" ]; then
	warn "missing:$missing"
	if [ -n "$PKG" ] && confirm "Install with: $PKG$missing ?"; then
		# shellcheck disable=SC2086
		$PKG $missing && ok "installed$missing" || warn "install failed — install$missing manually and re-run"
	else
		warn "skipping install — these are required for the statusline/picker to work"
	fi
else
	ok "tmux, jq, git all present"
fi
echo

# --- Part 1: SSH key login (optional) --------------------------------------
say "SSH key login"
note "On YOUR laptop (the client), to use a 1Password-managed key:"
note "  1) 1Password → Settings → Developer → enable 'Use the SSH agent'"
note "  2) Create/import an SSH key item (Ed25519 is the default — good)"
note "  3) In ~/.ssh/config on your laptop:  Host *  ->  IdentityAgent ~/.1password/agent.sock"
note "     (macOS socket: '~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock')"
note "  4) Copy the PUBLIC key (the 'ssh-ed25519 AAAA…' string) and paste it below."
echo
if confirm "Add a public key to ~/.ssh/authorized_keys on this machine now?"; then
	pubkey="$(ask "Paste public key" "")"
	if [ -n "$pubkey" ]; then
		mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
		touch "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"
		if grep -qF "$pubkey" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
			ok "key already present — nothing to do"
		else
			printf '%s\n' "$pubkey" >> "$HOME/.ssh/authorized_keys"
			ok "key added to ~/.ssh/authorized_keys"
		fi
		warn "TEST IT from a new terminal before closing this session."
		warn "Disabling password auth is intentionally NOT done here — do it manually once key login works."
	else
		note "no key entered — skipping"
	fi
else
	note "skipping SSH key step"
fi
echo

# --- Part 2: tmux session picker -------------------------------------------
say "tmux session picker (~/.tmux-login.sh)"
note "Define your projects. Each line: 'key name directory'"
note "  key = menu letter, name = tmux session name (no '.' or ':'), directory = start dir"
note "Enter one per line; blank line to finish. Press enter immediately to use the default (root only)."
proj_lines=""
while :; do
	line="$(ask "  project (key name dir)" "")"
	[ -z "$line" ] && break
	proj_lines="${proj_lines}${line}"$'\n'
done
if [ -z "$proj_lines" ]; then
	proj_block='projects="r root $HOME"'   # single-quoted: $HOME stays literal, expands at login
	note "using default: root only"
else
	proj_block="projects=\"$(printf '%s' "$proj_lines" | sed '/^$/d')\""
fi

if [ -f "$HOME/.tmux-login.sh" ] && ! confirm "~/.tmux-login.sh exists — overwrite?"; then
	note "keeping existing ~/.tmux-login.sh"
else
	# Copy the canonical script, swapping in the chosen projects= assignment.
	awk -v repl="$proj_block" '/^projects="/{print repl; skip=1; next} skip&&/^$/{skip=0} !skip{print}' \
		"$SCRIPTS/tmux-login.sh" > "$HOME/.tmux-login.sh"
	ok "wrote ~/.tmux-login.sh"
fi

# Wire into the login profile.
prof="$HOME/.profile"
[ -f "$HOME/.bash_profile" ] && prof="$HOME/.bash_profile"
if grep -q 'tmux-login.sh' "$prof" 2>/dev/null; then
	ok "login hook already present in $prof"
else
	{ echo ""; cat "$SCRIPTS/profile-snippet.sh"; } >> "$prof"
	ok "appended login hook to $prof"
fi
note "If your shell doesn't source $prof on login, add '. $prof' to the file it does source."
echo

# --- Part 2b: tmux copy/scrollback/history config --------------------------
say "tmux config (~/.tmux.conf — mouse, scrollback, history)"
tmuxconf="$HOME/.tmux.conf"
if [ ! -f "$tmuxconf" ]; then
	install -m 0644 "$SCRIPTS/tmux.conf" "$tmuxconf"
	ok "wrote ~/.tmux.conf"
else
	# Append only the settings that aren't already configured (idempotent).
	added=0
	grep -q '^[[:space:]]*set\(w\)\?[[:space:]].*mouse'         "$tmuxconf" || { echo 'set -g mouse on'            >> "$tmuxconf"; added=1; }
	grep -q '^[[:space:]]*set\(w\)\?[[:space:]].*history-limit' "$tmuxconf" || { echo 'set -g history-limit 50000' >> "$tmuxconf"; added=1; }
	if [ "$added" = 1 ]; then ok "appended missing tmux settings to existing ~/.tmux.conf"; else ok "~/.tmux.conf already has mouse + history-limit"; fi
fi
note "Reload in a running tmux with:  tmux source-file ~/.tmux.conf"
echo

# --- Part 3: statusline ----------------------------------------------------
say "Claude Code statusline (~/.claude/statusline.sh)"
mkdir -p "$HOME/.claude"
install -m 0755 "$SCRIPTS/statusline.sh" "$HOME/.claude/statusline.sh"
ok "installed ~/.claude/statusline.sh"

settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
if command -v jq >/dev/null 2>&1; then
	tmp="$(mktemp)"
	if jq '.statusLine = {type:"command", command:"~/.claude/statusline.sh", padding:0}' "$settings" > "$tmp" 2>/dev/null; then
		mv "$tmp" "$settings"; ok "registered statusLine in settings.json"
	else
		rm -f "$tmp"; warn "couldn't parse $settings — add the statusLine block manually (see README)"
	fi
else
	warn "jq missing — add the statusLine block to $settings manually (see README)"
fi
echo

# --- Done ------------------------------------------------------------------
say "Done"
ok "Open a NEW SSH session to see the tmux picker (keep this one open as a safety net)."
ok "The statusline appears at the bottom of Claude Code on its next render."
note "Add projects later by editing the projects=\"...\" block in ~/.tmux-login.sh."
