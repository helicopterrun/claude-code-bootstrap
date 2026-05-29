# --- Interactive tmux session picker on SSH/mosh login ---------------------
# Append this block to ~/.profile (or ~/.bash_profile / ~/.zprofile, whichever
# your login shell sources). The guards keep it from firing on non-interactive
# or non-SSH shells, and the infocmp check prevents an unknown $TERM from
# exec'ing a tmux that instantly dies and strands the login.
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
# --------------------------------------------------------------------------- #
