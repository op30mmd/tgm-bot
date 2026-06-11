# handlers/commands.zsh

target_from_reply() {  # <upd>
  print -r -- "$1" | jq_get '.message.reply_to_message.from.id'
}

parse_duration() {
  local d=$1 n=${1%[smhd]} unit=${1: -1}
  [[ $d == <-> ]] && { print -- $(( d*60 )); return; }   # bare number = minutes
  case $unit in
    s) print -- $n ;;  m) print -- $(( n*60 )) ;;
    h) print -- $(( n*3600 )) ;; d) print -- $(( n*86400 )) ;;
    *) print -- 0 ;;
  esac
}

cmd_help() {
    local chat=$1
    local msg="<b>Available commands:</b>
/ban - Ban user (reply)
/unban &lt;id&gt; - Unban user
/kick - Kick user (reply)
/mute [duration] - Mute user (reply)
/unmute - Unmute user (reply)
/warn [reason] - Warn user (reply)
/unwarn - Reset warnings (reply)
/settings &lt;key&gt; &lt;value&gt; - Set chat settings"
    send_message "$chat" "$msg"
}

cmd_ban() {  # <chat> <actor> <upd> <args>
  local chat=$1 actor=$2 upd=$3 args=$4
  can_moderate "$chat" "$actor" || { send_message "$chat" "⛔ You can't do that."; return; }

  local target=$(target_from_reply "$upd")
  [[ -z $target ]] && target=${args%%[[:space:]]*}
  [[ -z $target ]] && { send_message "$chat" "Reply to a user or pass an id."; return; }

  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't ban an admin."; return; }

  if ban_member "$chat" "$target" >/dev/null; then
    send_message "$chat" "🔨 Banned <code>$(html_esc "${target}")</code>."
    audit "$chat" "BAN" "$actor" "$target" "$args"
  else
    send_message "$chat" "Failed to ban (check my admin rights)."
  fi
}

cmd_unban() {
    local chat=$1 actor=$2 args=$3
    can_moderate "$chat" "$actor" || return
    local target=${args%%[[:space:]]*}
    [[ -z $target ]] && { send_message "$chat" "Pass an id to unban."; return; }
    if unban_member "$chat" "$target" >/dev/null; then
        send_message "$chat" "🔓 Unbanned <code>$(html_esc "${target}")</code>."
        audit "$chat" "UNBAN" "$actor" "$target" ""
    fi
}

cmd_kick() {
    local chat=$1 actor=$2 upd=$3
    can_moderate "$chat" "$actor" || return
    local target=$(target_from_reply "$upd")
    [[ -z $target ]] && { send_message "$chat" "Reply to the user to kick."; return; }
    is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't kick an admin."; return; }
    if kick_member "$chat" "$target" >/dev/null; then
        send_message "$chat" "👢 Kicked <code>$(html_esc "${target}")</code>."
        audit "$chat" "KICK" "$actor" "$target" ""
    fi
}

cmd_mute() {  # <chat> <actor> <upd> <args>
  local chat=$1 actor=$2 upd=$3 args=$4
  can_moderate "$chat" "$actor" || return
  local target=$(target_from_reply "$upd")
  [[ -z $target ]] && { send_message "$chat" "Reply to the user to mute."; return; }
  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't mute an admin."; return; }
  local secs=$(parse_duration "${args%%[[:space:]]*}")
  local until=0; (( secs > 0 )) && until=$(( $(date +%s) + secs ))
  if mute_member "$chat" "$target" ${until:#0} >/dev/null; then
    local dur=$(html_esc "${args%%[[:space:]]*}")
    send_message "$chat" "🔇 Muted <code>$(html_esc "${target}")</code>${secs:+ for ${dur}}."
    audit "$chat" "MUTE" "$actor" "$target" "$args"
  fi
}

cmd_unmute() {
    local chat=$1 actor=$2 upd=$3
    can_moderate "$chat" "$actor" || return
    local target=$(target_from_reply "$upd")
    [[ -z $target ]] && { send_message "$chat" "Reply to the user to unmute."; return; }
    if unmute_member "$chat" "$target" >/dev/null; then
        send_message "$chat" "🔊 Unmuted <code>$(html_esc "${target}")</code>."
        audit "$chat" "UNMUTE" "$actor" "$target" ""
    fi
}

cmd_warn() {  # <chat> <actor> <upd> <reason>
  local chat=$1 actor=$2 upd=$3 reason=$4
  can_moderate "$chat" "$actor" || return
  local target=$(target_from_reply "$upd")
  [[ -z $target ]] && { send_message "$chat" "Reply to the user to warn."; return; }
  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't warn an admin."; return; }

  local count=$(warn_add "$chat" "$target")
  if (( count >= WARN_LIMIT )); then
    case $WARN_ACTION in
      ban)  ban_member  "$chat" "$target" ;;
      kick) kick_member "$chat" "$target" ;;
      mute) mute_member "$chat" "$target" ;;
    esac
    warn_reset "$chat" "$target"
    send_message "$chat" "⚠️ <code>$(html_esc "${target}")</code> hit ${WARN_LIMIT} warnings → <b>${WARN_ACTION}</b>."
    audit "$chat" "WARN_LIMIT/${WARN_ACTION}" "$actor" "$target" "$reason"
  else
    local r_esc=$(html_esc "$reason")
    send_message "$chat" "⚠️ Warned <code>$(html_esc "${target}")</code> (${count}/${WARN_LIMIT}). ${reason:+Reason: ${r_esc}}"
    audit "$chat" "WARN" "$actor" "$target" "$reason"
  fi
}

cmd_unwarn() {
    local chat=$1 actor=$2 upd=$3
    can_moderate "$chat" "$actor" || return
    local target=$(target_from_reply "$upd")
    [[ -z $target ]] && { send_message "$chat" "Reply to the user to unwarn."; return; }
    warn_reset "$chat" "$target"
    send_message "$chat" "✅ Reset warnings for <code>$(html_esc "${target}")</code>."
    audit "$chat" "UNWARN" "$actor" "$target" ""
}

cmd_settings() {
    local chat=$1 actor=$2 args=$3
    can_moderate "$chat" "$actor" || return
    local key=${args%%[[:space:]]*}
    local val=${args#*[[:space:]]}
    [[ $key == $args ]] && val=""
    if [[ -z $key ]]; then
        send_message "$chat" "Usage: /settings &lt;key&gt; &lt;value&gt;"
        return
    fi
    setting_set "$chat" "$key" "$val"
    send_message "$chat" "✅ Set <b>$(html_esc "$key")</b> to <code>$(html_esc "$val")</code>."
}

handle_message() {
  local upd=$1
  local chat=$(print -r -- "$upd" | jq_get '.message.chat.id')
  local uid=$(print -r -- "$upd"  | jq_get '.message.from.id')
  local mid=$(print -r -- "$upd"  | jq_get '.message.message_id')
  local text=$(print -r -- "$upd" | jq_get '.message.text')

  # 1) Run passive filters (may delete + return non-zero to stop)
  run_filters "$chat" "$uid" "$mid" "$text" "$upd" || return

  # 2) Command routing (commands start with / )
  [[ $text == /* ]] || return
  local cmd=${${text%%[[:space:]]*}#/}   # strip leading / and args
  cmd=${cmd%%@*}                          # strip @botname suffix
  local args=${text#*[[:space:]]}; [[ $args == $text ]] && args=""

  case $cmd in
    help|rules)            cmd_help     "$chat" ;;
    ban)                   cmd_ban      "$chat" "$uid" "$upd" "$args" ;;
    unban)                 cmd_unban    "$chat" "$uid" "$args" ;;
    kick)                  cmd_kick     "$chat" "$uid" "$upd" ;;
    mute)                  cmd_mute     "$chat" "$uid" "$upd" "$args" ;;
    unmute)                cmd_unmute   "$chat" "$uid" "$upd" ;;
    warn)                  cmd_warn     "$chat" "$uid" "$upd" "$args" ;;
    unwarn)                cmd_unwarn   "$chat" "$uid" "$upd" ;;
    settings)              cmd_settings "$chat" "$uid" "$args" ;;
    *) : ;;  # unknown command: ignore
  esac
}

dispatch() {
  local upd=$1
  if   [[ $(print -r -- "$upd" | jq 'has("callback_query")') == true ]]; then
    handle_callback "$upd"
  elif [[ $(print -r -- "$upd" | jq 'has("chat_join_request")') == true ]]; then
    handle_join_request "$upd"
  elif [[ $(print -r -- "$upd" | jq '.message.new_chat_members != null') == true ]]; then
    handle_new_members "$upd"
  elif [[ $(print -r -- "$upd" | jq '.message.left_chat_member != null') == true ]]; then
    handle_left_member "$upd"
  elif [[ $(print -r -- "$upd" | jq 'has("message")') == true ]]; then
    handle_message "$upd"
  fi
}
