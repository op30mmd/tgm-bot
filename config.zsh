# config.zsh — source this; NEVER commit it.
# Keep perms tight: chmod 600 config.zsh

export TG_TOKEN="123456789:AAEx-your-token-here"
export TG_API="https://api.telegram.org/bot${TG_TOKEN}"

# Bot owner(s): full control, cannot be demoted by group admins.
typeset -ga BOT_OWNERS=( 11111111 22222222 )

# Optional audit log channel/group id (bot must be a member/admin there).
export AUDIT_CHAT_ID=""

# Tunables
export POLL_TIMEOUT=30          # long-poll seconds
export FLOOD_MAX=6              # messages...
export FLOOD_WINDOW=8          # ...within N seconds => flood
export WARN_LIMIT=3            # warnings before auto-action
export WARN_ACTION="mute"      # mute | kick | ban
export CAPTCHA_ENABLED=1
export CAPTCHA_TIMEOUT=90       # seconds to solve or get kicked
export DATA_DIR="${0:A:h}/data"
