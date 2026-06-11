# lib/log.zsh
_ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log_info()  { print -r -- "$(_ts) INFO  $*" >&2; }
log_warn()  { print -r -- "$(_ts) WARN  $*" >&2; }
log_error() { print -r -- "$(_ts) ERROR $*" >&2; }

# Mirror moderation events to an audit channel
audit() {  # <chat> <action> <actor> <target> <reason>
  log_info "AUDIT chat=$1 action=$2 actor=$3 target=$4 reason=$5"
  [[ -n $AUDIT_CHAT_ID ]] || return
  send_message "$AUDIT_CHAT_ID" "📋 <b>$2</b>
chat: <code>$1</code>
by: <code>$3</code> → <code>$4</code>
${5:+reason: $5}" >/dev/null
}
