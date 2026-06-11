# handlers/members.zsh
handle_new_members() {
  local upd=$1
  local chat=$(print -r -- "$upd" | jq_get '.message.chat.id')
  print -r -- "$upd" | jq -c '.message.new_chat_members[]' | while IFS= read -r m; do
    local uid=$(print -r -- "$m" | jq_get '.id')
    local name=$(print -r -- "$m" | jq_get '.first_name')
    local user=$(print -r -- "$m" | jq_get '.username')
    [[ -n $user ]] && user_save "$uid" "$user"

    [[ $(print -r -- "$m" | jq_get '.is_bot') == true ]] && continue

    if (( CAPTCHA_ENABLED )); then
      mute_member "$chat" "$uid" >/dev/null
      local kb='{"inline_keyboard":[[{"text":"✅ I am human","callback_data":"captcha:'"$uid"'"}]]}'
      send_message "$chat" "👋 Welcome <b>$(html_esc "${name}")</b>! Tap the button within ${CAPTCHA_TIMEOUT}s to chat." HTML "$kb"
      ( sleep $CAPTCHA_TIMEOUT
        # if still muted (didn't solve), kick
        local st=$(get_member "$chat" "$uid" | jq_get '.result.status')
        [[ $st == "restricted" ]] && kick_member "$chat" "$uid" >/dev/null ) &
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
