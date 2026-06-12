# lib/store.zsh

typeset -gA CACHE_WARNINGS
typeset -gA CACHE_SETTINGS
typeset -gA CACHE_USERS

_store_init() {
  mkdir -p "$DATA_DIR"
  [[ -f $DATA_DIR/warnings.json ]] || print -r -- '{}' > $DATA_DIR/warnings.json
  [[ -f $DATA_DIR/settings.json ]] || print -r -- '{}' > $DATA_DIR/settings.json
  [[ -f $DATA_DIR/users.json ]]    || print -r -- '{}' > $DATA_DIR/users.json

  # Load warning counts into memory
  local warn_data
  warn_data=$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' $DATA_DIR/warnings.json 2>/dev/null)
  while IFS=$'\t' read -r k v; do
    [[ -n $k ]] && CACHE_WARNINGS[$k]=$v
  done <<< "$warn_data"

  # Load resolved username mappings into memory
  local user_data
  user_data=$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' $DATA_DIR/users.json 2>/dev/null)
  while IFS=$'\t' read -r k v; do
    [[ -n $k ]] && CACHE_USERS[$k]=$v
  done <<< "$user_data"

  # Load chat settings into memory (flattened as "chat:key")
  local settings_data
  settings_data=$(jq -r 'to_entries[] | .key as $chat | .value | to_entries[] | "\($chat):\(.key)\t\(.value)"' $DATA_DIR/settings.json 2>/dev/null)
  while IFS=$'\t' read -r k v; do
    [[ -n $k ]] && CACHE_SETTINGS[$k]=$v
  done <<< "$settings_data"
}

# Atomic jq update: _store_update <file> <jq-filter> [jq-args...]
_store_update() {
  local file=$1; shift
  local tmp=$(mktemp "${file}.XXXXXX")
  jq "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Warnings keyed by "chat:user"
warn_count() {
  print -r -- "${CACHE_WARNINGS[$1:$2]:-0}"
}

warn_add() {
  local k="$1:$2"
  local curr=${CACHE_WARNINGS[$k]:-0}
  local new=$(( curr + 1 ))
  CACHE_WARNINGS[$k]=$new
  # Write back asynchronously in the background
  ( _store_update $DATA_DIR/warnings.json --arg k "$k" '.[$k] = ((.[$k]//0)+1)' ) &
  print -r -- "$new"
}

warn_reset() {
  local k="$1:$2"
  unset "CACHE_WARNINGS[$k]"
  ( _store_update $DATA_DIR/warnings.json --arg k "$k" 'del(.[$k])' ) &
}

# Per-chat setting get/set
setting_get() {
  print -r -- "${CACHE_SETTINGS[$1:$2]:-}"
}

setting_set() {
  local k="$1:$2"
  CACHE_SETTINGS[$k]="$3"
  ( _store_update $DATA_DIR/settings.json --arg c "$1" --arg k "$2" --arg v "$3" '.[$c][$k] = $v' ) &
}
