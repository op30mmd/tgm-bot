# lib/log.zsh
_ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log_info()  { print -r -- "$(_ts) INFO  $*" >&2; }
log_warn()  { print -r -- "$(_ts) WARN  $*" >&2; }
log_error() { print -r -- "$(_ts) ERROR $*" >&2; }

# Mirror moderation events to an audit channel
audit() {  # <chat> <action> <actor> <target> <reason>
  log_info "AUDIT chat=$1 action=$2 actor=$3 target=$4 reason=$5"
  [[ -n $AUDIT_CHAT_ID ]] || return
  local chat_esc=$(html_esc "$1")
  local act_esc=$(html_esc "$2")
  local actor_esc=$(html_esc "$3")
  local target_esc=$(html_esc "$4")
  local reason_esc=$(html_esc "$5")
  send_message "$AUDIT_CHAT_ID" "📋 <b>$act_esc</b>
chat: <code>$chat_esc</code>
by: <code>$actor_esc</code> → <code>$target_esc</code>
${5:+reason: $reason_esc}" >/dev/null
}
