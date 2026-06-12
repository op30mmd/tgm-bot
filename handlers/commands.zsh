# handlers/commands.zsh

target_from_reply() { # <upd>
  print -r -- "$1" | jq_get '.message.reply_to_message.from.id'
}

parse_duration() {
  local d=$1 n=${1%[smhd]} unit=${1: -1}
  [[ $d == <-> ]] && { print -- $(( d*60 )); return; } # bare number = minutes
  case $unit in
    s) print -- $n ;; m) print -- $(( n*60 )) ;;
    h) print -- $(( n*3600 )) ;; d) print -- $(( n*86400 )) ;;
    *) print -- 0 ;;
  esac
}

cmd_help() {
  local chat=$1
  local msg="<b>Available commands:</b>
/help or /rules - Display this help menu
/ban - Ban user (reply)
/unban &lt;id&gt; - Unban user
/kick - Kick user (reply)
/mute [duration] - Mute user (reply)
/unmute - Unmute user (reply)
/warn [reason] - Warn user (reply)
/unwarn - Reset warnings (reply)
/settings &lt;key&gt; &lt;value&gt; - Set chat settings
/addword &lt;word&gt; - Block a word
/delword &lt;word&gt; - Unblock a word

Note: To resolve a @username, I must have seen them in the group or they must have a public profile."
  send_message "$chat" "$msg"
}

cmd_ban() { # <chat> <actor> <upd> <args...>
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || { send_message "$chat" "⛔ You can't do that."; return; }

  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user. Reply to them or use a numeric id."; return; }

  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't ban an admin."; return; }

  if ban_member "$chat" "$target"; then
    send_message "$chat" "🔨 Banned <code>$(html_esc "${target}")</code>."
    audit "$chat" "BAN" "$actor" "$target" "$*"
  else
    send_message "$chat" "Failed to ban (check my admin rights)."
  fi
}

cmd_unban() {
  local chat=$1 actor=$2; shift 2
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "" "$*") # no upd context for unban usually
  [[ -z $target ]] && { send_message "$chat" "Pass a numeric id or @username to unban."; return; }
  if unban_member "$chat" "$target"; then
    send_message "$chat" "🔓 Unbanned <code>$(html_esc "${target}")</code>."
    audit "$chat" "UNBAN" "$actor" "$target" ""
  fi
}

cmd_kick() {
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user."; return; }
  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't kick an admin."; return; }
  if kick_member "$chat" "$target"; then
    send_message "$chat" "👢 Kicked <code>$(html_esc "${target}")</code>."
    audit "$chat" "KICK" "$actor" "$target" ""
  fi
}

cmd_mute() { # <chat> <actor> <upd> <args...>
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user."; return; }

  # Find duration: if we used an arg for target, duration is $2, else $1
  local dur_arg=$1
  [[ $(print -r -- "$upd" | jq_get '.message.reply_to_message') == "" ]] && dur_arg=$2

  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't mute an admin."; return; }
  local secs=$(parse_duration "$dur_arg")
  # Telegram treats until_date < 30s as permanent. Ensure at least 31s if timed.
  (( secs > 0 && secs < 31 )) && secs=31
  local until=0; (( secs > 0 )) && until=$(( $(date +%s) + secs ))
  if mute_member "$chat" "$target" ${until:#0}; then
    local dur=$(html_esc "$dur_arg")
    send_message "$chat" "🔇 Muted <code>$(html_esc "${target}")</code>${${secs:#0}:+ for ${dur}}."
    audit "$chat" "MUTE" "$actor" "$target" "$*"
  fi
}

cmd_unmute() {
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user."; return; }
  if unmute_member "$chat" "$target"; then
    send_message "$chat" "🔊 Unmuted <code>$(html_esc "${target}")</code>."
    audit "$chat" "UNMUTE" "$actor" "$target" ""
  fi
}

cmd_warn() { # <chat> <actor> <upd> <args...>
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user."; return; }

  local reason_idx=1
  [[ $(print -r -- "$upd" | jq_get '.message.reply_to_message') == "" ]] && reason_idx=2
  local reason="${(j: :)@[reason_idx,-1]}"
  is_owner "$target" || is_chat_admin "$chat" "$target" && { send_message "$chat" "🛡️ Can't warn an admin."; return; }

  local count=$(warn_add "$chat" "$target")
  if (( count >= WARN_LIMIT )); then
    case $WARN_ACTION in
      ban) ban_member "$chat" "$target" ;;
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
  local chat=$1 actor=$2 upd=$3; shift 3
  can_moderate "$chat" "$actor" || return
  local target=$(resolve_target "$upd" "$*")
  [[ -z $target ]] && { send_message "$chat" "Couldn't resolve that user."; return; }
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

cmd_addword() {
  local chat=$1 actor=$2; shift 2
  can_moderate "$chat" "$actor" || return
  local word="${(j: :)@}"
  word=${word:l}
  [[ -z $word ]] && { send_message "$chat" "Usage: /addword &lt;word&gt;"; return; }
  [[ $word == *,* ]] && { send_message "$chat" "❌ Words cannot contain commas."; return; }

  local bad=$(setting_get "$chat" "banned_words")
  local words; words=( ${(s:,:)bad} )
  if [[ ${words[(r)$word]} == $word ]]; then
    send_message "$chat" "<code>$(html_esc "$word")</code> is already in the list."
    return
  fi

  words+=$word
  setting_set "$chat" "banned_words" "${(j:,:)words}"
  send_message "$chat" "✅ Added <code>$(html_esc "$word")</code> to blocked words."
  audit "$chat" "ADD_WORD" "$actor" "chat" "$word"
}

cmd_delword() {
  local chat=$1 actor=$2; shift 2
  can_moderate "$chat" "$actor" || return
  local word="${(j: :)@}"
  word=${word:l}
  [[ -z $word ]] && { send_message "$chat" "Usage: /delword &lt;word&gt;"; return; }

  local bad=$(setting_get "$chat" "banned_words")
  local words; words=( ${(s:,:)bad} )
  if [[ ${words[(r)$word]} != $word ]]; then
    send_message "$chat" "<code>$(html_esc "$word")</code> is not in the list."
    return
  fi

  words=( ${words:#$word} )
  setting_set "$chat" "banned_words" "${(j:,:)words}"
  send_message "$chat" "✅ Removed <code>$(html_esc "$word")</code> from blocked words."
  audit "$chat" "DEL_WORD" "$actor" "chat" "$word"
}

handle_message() {
  local upd=$1
  local chat=$(print -r -- "$upd" | jq_get '.message.chat.id')
  local uid=$(print -r -- "$upd" | jq_get '.message.from.id')
  local mid=$(print -r -- "$upd" | jq_get '.message.message_id')
  local text=$(print -r -- "$upd" | jq_get '.message.text')

  # 0) Passive user harvest
  harvest_users "$upd"

  # 1) Run passive filters (may delete + return non-zero to stop)
  run_filters "$chat" "$uid" "$mid" "$text" "$upd" || return

  # 2) Command routing (commands start with / )
  [[ $text == /* ]] || return
  local words; words=( ${(z)text} )
  local cmd=${words[1]#/}
  cmd=${cmd%%@*}
  local args_str=${text#$words[1]}
  args_str=${args_str# } # strip leading space if present

  case $cmd in
    help|rules) cmd_help "$chat" ;;
    ban) cmd_ban "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    unban) cmd_unban "$chat" "$uid" "${words[@]:1}" ;;
    kick) cmd_kick "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    mute) cmd_mute "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    unmute) cmd_unmute "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    warn) cmd_warn "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    unwarn) cmd_unwarn "$chat" "$uid" "$upd" "${words[@]:1}" ;;
    settings) cmd_settings "$chat" "$uid" "$args_str" ;;
    addword) cmd_addword "$chat" "$uid" "${words[@]:1}" ;;
    delword) cmd_delword "$chat" "$uid" "${words[@]:1}" ;;
    *) : ;; # unknown command: ignore
  esac
}

dispatch() {
  local upd=$1
  # Resolve the update type in a single process execution
  local type
  type=$(print -r -- "$upd" | jq -r '
    if has("callback_query") then "callback_query"
    elif has("chat_member") then "chat_member"
    elif has("my_chat_member") then "my_chat_member"
    elif .message.chat_join_request != null then "chat_join_request"
    elif .message.new_chat_members != null then "new_chat_members"
    elif .message.left_chat_member != null then "left_chat_member"
    elif has("message") then "message"
    else "unknown" end
  ')

  case $type in
    callback_query) handle_callback "$upd" ;;
    chat_member|my_chat_member) handle_chat_member "$upd" ;;
    chat_join_request) handle_join_request "$upd" ;;
    new_chat_members) handle_new_members "$upd" ;;
    left_chat_member) handle_left_member "$upd" ;;
    message) handle_message "$upd" ;;
  esac
}
