#!/usr/bin/env bash
# Claude Code statusline — reads JSON on stdin, prints colored status to stdout.
#
# Line 1 (status): location/git │ session state │ rate limits
# Line 2 (hint):   Claude commands + tmux shortcuts (desktop only)
# When space is constrained (<80 cols) the context bar and hint line are dropped.
#
# Requires: jq, git. Register in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 } }

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
