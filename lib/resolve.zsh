# lib/resolve.zsh

# Record a username -> id mapping (lowercased key). No-op without a username.
cache_user() {  # cache_user <id> <username>
  [[ -z $1 || $1 == null || -z $2 || $2 == null ]] && return
  local u="${2:l}"
  if [[ ${CACHE_USERS[$u]:-} != $1 ]]; then
    CACHE_USERS[$u]=$1
    ( _store_update $DATA_DIR/users.json --arg u "$u" --arg i "$1" '.[$u] = $i' ) &
  fi
}

# Passively harvest every user we can see in an update, so the cache fills up.
harvest_users() {  # <upd>
  local upd=$1
  # message sender
  cache_user "$(print -r -- "$upd" | jq_get '.message.from.id')" \
             "$(print -r -- "$upd" | jq_get '.message.from.username')"
  # replied-to author
  cache_user "$(print -r -- "$upd" | jq_get '.message.reply_to_message.from.id')" \
             "$(print -r -- "$upd" | jq_get '.message.reply_to_message.from.username')"
  # text_mention entities carry a full User object (for users with no @username)
  print -r -- "$upd" \
    | jq -c '.message.entities[]? | select(.type=="text_mention") | .user' \
    | while IFS= read -r u; do
        cache_user "$(print -r -- "$u" | jq_get '.id')" \
                   "$(print -r -- "$u" | jq_get '.username')"
      done
}

get_chat() { tg_call getChat -d "chat_id=$1"; }

# Resolve a bare/@username to an id: cache first, then getChat fallback.
resolve_username() {  # <@name|name> -> prints id or empty
  local u=${1#@};
  [[ $u == <-> ]] && { print -r -- "$u"; return; }
  u=${u:l}
  local id=${CACHE_USERS[$u]:-}
  if [[ -z $id ]]; then
    local resp=$(get_chat "@$u")
    if [[ $(print -r -- "$resp" | jq_get '.ok') == true ]]; then
        id=$(print -r -- "$resp" | jq_get '.result.id')   # public usernames only
        cache_user "$id" "$u"
    fi
  fi
  print -r -- "$id"
}

# Unified target resolver used by every moderation command.
resolve_target() {  # <upd> <args> -> prints target id (or empty)
  local upd=$1 tok=${2%%[[:space:]]*} id
  # 1) reply (most reliable)
  id=$(print -r -- "$upd" | jq_get '.message.reply_to_message.from.id')
  [[ -n $id ]] && { print -r -- "$id"; return; }
  # 2) text_mention entity embedded in the command message
  id=$(print -r -- "$upd" \
        | jq -r '[.message.entities[]? | select(.type=="text_mention") | .user.id][0] // empty')
  [[ -n $id ]] && { print -r -- "$id"; return; }
  # 3) @username argument -> cache / getChat
  [[ $tok == @* ]] && { resolve_username "$tok"; return; }
  # 4) raw numeric id
  [[ $tok == <-> ]] && print -r -- "$tok"
}
