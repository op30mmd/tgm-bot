# lib/store.zsh

_store_init() {
  mkdir -p "$DATA_DIR"
  [[ -f $DATA_DIR/warnings.json ]] || echo '{}' > $DATA_DIR/warnings.json
  [[ -f $DATA_DIR/settings.json ]] || echo '{}' > $DATA_DIR/settings.json
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
