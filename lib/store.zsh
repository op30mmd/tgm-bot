# lib/store.zsh

_store_init() {
  mkdir -p "$DATA_DIR"
  [[ -f $DATA_DIR/warnings.json ]] || print -r -- '{}' > $DATA_DIR/warnings.json
  [[ -f $DATA_DIR/settings.json ]] || print -r -- '{}' > $DATA_DIR/settings.json
  [[ -f $DATA_DIR/users.json ]]    || print -r -- '{}' > $DATA_DIR/users.json
}

# Atomic jq update: _store_update <file> <jq-filter> [jq-args...]
_store_update() {
  local file=$1; shift
  local tmp=$(mktemp)
  jq "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Warnings keyed by "chat:user"
warn_count() { jq -r --arg k "$1:$2" '.[$k] // 0' $DATA_DIR/warnings.json; }
warn_add()   { _store_update $DATA_DIR/warnings.json --arg k "$1:$2" '.[$k] = ((.[$k]//0)+1)'; warn_count "$1" "$2"; }
warn_reset() { _store_update $DATA_DIR/warnings.json --arg k "$1:$2" 'del(.[$k])'; }

# Per-chat setting get/set
setting_get() { jq -r --arg c "$1" --arg k "$2" '.[$c][$k] // empty' $DATA_DIR/settings.json; }
setting_set() { _store_update $DATA_DIR/settings.json --arg c "$1" --arg k "$2" --arg v "$3" '.[$c][$k] = $v'; }

# Mapping @username or "id" to user_id
user_save() { # user_save <id> <username_no_at>
  [[ -z $2 ]] && return
  _store_update $DATA_DIR/users.json --arg id "$1" --arg u "${2:l}" '.[$u] = $id'
}
user_resolve() { # user_resolve "@username" or "id" [chat_id] -> prints id
  local input=${1#@}
  local chat=$2
  if [[ $input == <-> ]]; then
    print -r -- "$input"
    return
  fi

  local res=$(jq -r --arg u "${input:l}" '.[$u] // empty' $DATA_DIR/users.json)
  if [[ -z $res && -n $chat ]]; then
    # Try to find in chat admins
    local admins=$(tg_call getChatAdministrators -d "chat_id=$chat")
    if [[ $(print -r -- "$admins" | jq_get '.ok') == true ]]; then
      res=$(print -r -- "$admins" | jq -r --arg u "${input:l}" '.result[] | select(.user.username | ascii_downcase == $u) | .user.id' | head -n1)
      [[ -n $res ]] && user_save "$res" "$input"
    fi
  fi
  print -r -- "$res"
}
