# lib/api.zsh
source "${0:A:h}/json.zsh"

# tg_call <method> [curl args...] -> prints raw JSON response
tg_call() {
  local method=$1; shift
  local resp http
  local attempt=0
  while (( attempt < 4 )); do
    resp=$(curl -sS -w $'\n%{http_code}' \
           -X POST "${TG_API}/${method}" "$@")
    http=${resp##*$'\n'}
    resp=${resp%$'\n'*}
    case $http in
      200) print -r -- "$resp"; return 0 ;;
      429)
        # Respect retry_after from Telegram
        local ra=$(print -r -- "$resp" | jq_get '.parameters.retry_after')
        sleep ${ra:-3} ;;
      *)
        log_warn "API ${method} -> HTTP ${http}: $(print -r -- "$resp" | jq_get '.description')"
        sleep 2 ;;
    esac
    (( attempt++ ))
  done
  print -r -- "$resp"; return 1
}

# Convenience wrappers (all use form fields via curl -d / --data-urlencode)
send_message() {  # send_message <chat_id> <text> [parse_mode] [reply_markup_json]
  local chat=$1 text=$2 mode=${3:-HTML} markup=$4
  local args=( --data-urlencode "chat_id=${chat}"
               --data-urlencode "text=${text}"
               --data-urlencode "parse_mode=${mode}"
               --data-urlencode "disable_web_page_preview=true" )
  [[ -n $markup ]] && args+=( --data-urlencode "reply_markup=${markup}" )
  tg_call sendMessage "${args[@]}"
}

delete_message() { tg_call deleteMessage -d "chat_id=$1" -d "message_id=$2"; }

ban_member() {    # ban_member <chat> <user> [until_unix]
  tg_call banChatMember -d "chat_id=$1" -d "user_id=$2" \
    ${3:+-d "until_date=$3"} -d "revoke_messages=true"
}

unban_member() { tg_call unbanChatMember -d "chat_id=$1" -d "user_id=$2" -d "only_if_banned=true"; }

mute_member() {   # mute_member <chat> <user> [until_unix]
  tg_call restrictChatMember -d "chat_id=$1" -d "user_id=$2" \
    --data-urlencode "permissions=$(perms_json 0)" ${3:+-d "until_date=$3"}
}

unmute_member() {
  # unbanChatMember with only_if_banned=false (default) lifts ALL restrictions
  # and restores status to "member". This is more reliable than restrictChatMember.
  tg_call unbanChatMember -d "chat_id=$1" -d "user_id=$2" -d "only_if_banned=false"
}

kick_member() {   # ban then immediately unban = kick (can rejoin)
  ban_member "$1" "$2"; sleep 1; unban_member "$1" "$2"
}

get_member()   { tg_call getChatMember -d "chat_id=$1" -d "user_id=$2"; }
answer_cbq()   { tg_call answerCallbackQuery -d "callback_query_id=$1" --data-urlencode "text=${2:-}"; }
