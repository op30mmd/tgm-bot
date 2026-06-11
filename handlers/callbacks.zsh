# handlers/callbacks.zsh
handle_callback() {
  local upd=$1
  local cbid=$(print -r -- "$upd" | jq_get '.callback_query.id')
  local from=$(print -r -- "$upd" | jq_get '.callback_query.from.id')
  local chat=$(print -r -- "$upd" | jq_get '.callback_query.message.chat.id')
  local data=$(print -r -- "$upd" | jq_get '.callback_query.data')

  case $data in
    captcha:*)
      local target=${data#captcha:}
      log_info "CAPTCHA: button click from=$from target=$target chat=$chat"
      if [[ $from == $target ]]; then
        local mid=$(print -r -- "$upd" | jq_get '.callback_query.message.message_id')
        log_info "CAPTCHA: user=$from solved it, unmuting"
        unmute_member "$chat" "$target"
        delete_message "$chat" "$mid"
        answer_cbq "$cbid" "Verified ✅ — welcome!"
      else
        log_info "CAPTCHA: user=$from tried to click button for target=$target"
        answer_cbq "$cbid" "This button isn't for you."
      fi ;;
    *) answer_cbq "$cbid" "" ;;
  esac
}
