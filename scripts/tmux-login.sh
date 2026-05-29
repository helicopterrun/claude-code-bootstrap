# ~/.tmux-login.sh — interactive tmux session picker for SSH logins.
#
# Sourced from ~/.profile AFTER its SSH / interactive / $TERM guards pass
# (see profile-snippet.sh). Meant to be SOURCED, not executed: it uses
# `return` (not `exit`) for the no-tmux paths so you land in a normal login
# shell. The attach/new paths `exec tmux ...`, replacing the login shell, so
# quitting tmux logs you out (the usual tmux-on-login behavior).
#
# To add a project: add one "key name dir" line to $projects below.
# - key:  the letter you press in the menu
# - name: the tmux session name (must not contain '.' or ':')
# - dir:  the directory the session starts in

# key  session-name   start-directory
projects="r root $HOME"
# Examples — uncomment/add your own (one per line, inside the quotes):
# projects="h home-assistant $HOME/home-assistant
# a agent $HOME/agent
# e esphome $HOME/esphome
# r root $HOME"

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
