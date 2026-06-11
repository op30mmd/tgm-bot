# handlers/filters.zsh
typeset -gA FLOOD_TS # key "chat:user" -> space-separated unix timestamps

run_filters() { # <chat> <uid> <mid> <text> <upd> -> return 1 to halt
    local chat=$1 uid=$2 mid=$3 text=$4
  # never filter admins/owner
  can_moderate "$chat" "$uid" && return 0

  # --- Banned words ---
    local bad=$(setting_get "$chat" "banned_words")
    if [[ -n $bad ]]; then
    local w
  for w in ${(s:,:)bad}; do
    if [[ ${text:l} == *${w:l}* ]]; then
        delete_message "$chat" "$mid"
        local count=$(warn_add "$chat" "$uid")

        if (( count >= WARN_LIMIT )); then
          case $WARN_ACTION in
            ban) ban_member "$chat" "$uid" ;;
            kick) kick_member "$chat" "$uid" ;;
            mute) mute_member "$chat" "$uid" ;;
          esac
          warn_reset "$chat" "$uid"
          send_message "$chat" "⚠️ <code>$(html_esc "${uid}")</code> hit ${WARN_LIMIT} warnings → <b>${WARN_ACTION}</b>."
          audit "$chat" "WARN_LIMIT/${WARN_ACTION}" "bot" "$uid" "banned word: $w"
        else
          send_message "$chat" "⚠️ Warned <code>$(html_esc "${uid}")</code> (${count}/${WARN_LIMIT}) for banned word."
          audit "$chat" "WARN" "bot" "$uid" "banned word: $w"
        fi
  return 1
    fi
  done
    fi

  # --- Flood control (sliding window) ---
    local now=$(date +%s) key="${chat}:${uid}" kept=()
  for t in ${(s: :)FLOOD_TS[$key]}; do (( now - t < FLOOD_WINDOW )) && kept+=$t; done
  kept+=$now
  FLOOD_TS[$key]="${kept[*]}"
    if (( ${#kept} > FLOOD_MAX )); then
    mute_member "$chat" "$uid" $(( now + 300 )) # 5-min cooldown
      delete_message "$chat" "$mid"
    send_message "$chat" "🌊 <code>$(html_esc "${uid}")</code> muted 5m for flooding."
  audit "$chat" "FLOOD_MUTE" "bot" "$uid" ""
  return 1
    fi
  return 0
}
