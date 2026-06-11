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
      if [[ $from == $target ]]; then
        unmute_member "$chat" "$target" >/dev/null
        answer_cbq "$cbid" "Verified ✅ — welcome!"
      else
        answer_cbq "$cbid" "This button isn't for you."
      fi ;;
    *) answer_cbq "$cbid" "" ;;
  esac
}
