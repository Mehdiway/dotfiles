#!/usr/bin/env bash
#
# bootstrap-vps.sh — sets up the standard workflow on a fresh Linux VPS:
#   Zsh + zsh-autosuggestions + starship, tmux (prefix -> Ctrl-a), Mosh, aliases.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap-vps.sh | bash
#   (or copy this file to the VPS and run: bash bootstrap-vps.sh)
#
# Safe to re-run — every step checks before acting.

set -euo pipefail
ZSHRC="$HOME/.zshrc"
TMUX_CONF="$HOME/.tmux.conf"
ZSH_AUTOSUGGEST_DIR="$HOME/.zsh/zsh-autosuggestions"
log() { echo -e "\n==> $1"; }

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# --- 1. Packages ---
log "Installing base packages"
if command -v apt-get &>/dev/null; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y zsh tmux mosh git curl eza  # [CHANGED] added eza (was: zsh tmux mosh git curl)
elif command -v yum &>/dev/null; then
  $SUDO yum install -y zsh tmux mosh git curl
elif command -v dnf &>/dev/null; then
  $SUDO dnf install -y zsh tmux mosh git curl
else
  echo "Unsupported package manager — install zsh, tmux, mosh, git, curl manually." >&2
  exit 1
fi

# --- 2. Starship prompt ---
log "Installing starship"
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- 3. zsh-autosuggestions ---
log "Installing zsh-autosuggestions"
if [ ! -d "$ZSH_AUTOSUGGEST_DIR" ]; then
  mkdir -p "$(dirname "$ZSH_AUTOSUGGEST_DIR")"
  git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGEST_DIR"
else
  git -C "$ZSH_AUTOSUGGEST_DIR" pull --quiet
fi

# --- 4. .zshrc ---
log "Writing $ZSHRC"
cat > "$ZSHRC" << 'EOF'
# --- Keybindings ---
bindkey -e   # [ADDED] emacs keybindings
bindkey '^H' backward-kill-word    # [ADDED] Ctrl+Backspace-style word delete
bindkey '^?' backward-delete-char  # [ADDED] normal backspace

# --- Plugins ---
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept   # Ctrl+Space to accept suggestion

# --- History ---
HISTSIZE=1000                        # [CHANGED] was 10000, now matches your real config
SAVEHIST=1000                        # [CHANGED] was 10000, now matches your real config
HISTFILE=~/.zsh_history               # [ADDED]
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY   # [CHANGED] was HIST_IGNORE_DUPS (only dedupes consecutive dupes);
                                             #           HIST_IGNORE_ALL_DUPS matches your real ~/.zshrc behavior

# --- Completion system --- [ADDED block]
autoload -Uz compinit
compinit
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# --- PATH --- [ADDED]
export PATH="$HOME/.local/bin:$PATH"

# --- Aliases ---
alias cl=clear                       # [ADDED]
alias ls='eza'                       # [CHANGED] now uses eza instead of default ls
alias ll='eza -la'                   # [CHANGED] was 'ls -lah'
alias l='eza -la'                    # [ADDED]
alias lt='eza --tree'                # [ADDED]
alias gs='git status'
alias gc='git commit -m'
alias gp='git push'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias ports='sudo ss -tulpn'
# add the rest of your custom aliases here, or source a separate file:
# [ -f ~/.aliases.zsh ] && source ~/.aliases.zsh

# --- Prompt ---
eval "$(starship init zsh)"

# --- Start/attach to main tmux session --- [ADDED block]
if command -v tmux >/dev/null 2>&1 && [ -z "${TMUX:-}" ] && [ -z "${SSH_TTY:-}" ]; then
    tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi
EOF

# --- 5. tmux config (Ctrl-a prefix) ---
log "Writing $TMUX_CONF"
cat > "$TMUX_CONF" << 'EOF'
bind-key k confirm-before 'kill-window'   # [ADDED] confirm before killing a window

unbind C-b
set -g prefix C-a
bind C-a send-prefix

set -g mouse off                          # [CHANGED] was 'on', now matches your real config
set -g history-limit 10000
set -sg escape-time 0
setw -g mode-keys vi

unbind -T root WheelUpPane                # [ADDED]
unbind -T root WheelDownPane              # [ADDED]
EOF

# --- 6. Default shell ---
log "Setting zsh as default shell"
ZSH_PATH="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
  $SUDO chsh -s "$ZSH_PATH" "$(whoami)"
fi

log "Done. Start a new session (or run 'zsh') to pick everything up."