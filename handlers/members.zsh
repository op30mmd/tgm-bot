# handlers/members.zsh
handle_new_members() {
  local upd=$1
  local chat=$(print -r -- "$upd" | jq_get '.message.chat.id')
  print -r -- "$upd" | jq -c '.message.new_chat_members[]' | while IFS= read -r m; do
    local uid=$(print -r -- "$m" | jq_get '.id')
    local name=$(print -r -- "$m" | jq_get '.first_name')
    local user=$(print -r -- "$m" | jq_get '.username')
    cache_user "$uid" "$user"

    [[ $(print -r -- "$m" | jq_get '.is_bot') == true ]] && continue

    if (( CAPTCHA_ENABLED )); then
      log_info "CAPTCHA: starting for user=$uid chat=$chat"
      mute_member "$chat" "$uid" >/dev/null
      local kb='{"inline_keyboard":[[{"text":"✅ I am human","callback_data":"captcha:'"$uid"'"}]]}'
      local resp=$(send_message "$chat" "👋 Welcome <b>$(html_esc "${name}")</b>! Tap the button within ${CAPTCHA_TIMEOUT}s to chat." HTML "$kb")
      local mid=$(print -r -- "$resp" | jq_get '.result.message_id')
      ( sleep $CAPTCHA_TIMEOUT
        local mem=$(get_member "$chat" "$uid")
        local st=$(print -r -- "$mem" | jq_get '.result.status')
        local can_send=$(print -r -- "$mem" | jq_get '.result.can_send_messages')
        log_info "CAPTCHA: timeout check user=$uid chat=$chat status=$st can_send=$can_send"
        if [[ $st == "restricted" && $can_send == "false" ]]; then
          log_info "CAPTCHA: user=$uid failed to solve, kicking"
          kick_member "$chat" "$uid" >/dev/null
          delete_message "$chat" "$mid" >/dev/null
        fi ) &
    else
      local wmsg=$(setting_get "$chat" "welcome"); : ${wmsg:="Welcome, %NAME%!"}
      send_message "$chat" "${wmsg//\%NAME\%/$(html_esc "${name}")}"
    fi
  done
}

handle_left_member() {
    # Optional: handle when someone leaves
    :
}

handle_join_request() {
    # Optional: handle join requests
    :
}

handle_chat_member() {
  local upd=$1
  local key=$([[ $(print -r -- "$upd" | jq 'has("chat_member")') == true ]] && print -r -- "chat_member" || print -r -- "my_chat_member")
  local uid=$(print -r -- "$upd" | jq_get ".${key}.new_chat_member.user.id")
  local user=$(print -r -- "$upd" | jq_get ".${key}.new_chat_member.user.username")
  cache_user "$uid" "$user"
}
