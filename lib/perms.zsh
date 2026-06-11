# lib/perms.zsh

is_owner() { (( ${BOT_OWNERS[(Ie)$1]} )); }  # exact-match index

is_chat_admin() {  # is_chat_admin <chat> <user>
  local status
  status=$(get_member "$1" "$2" | jq_get '.result.status')
  [[ $status == "creator" || $status == "administrator" ]]
}

# Gate: returns 0 if user may moderate in this chat
can_moderate() {  # <chat> <user>
  is_owner "$2" && return 0
  is_chat_admin "$1" "$2"
}
