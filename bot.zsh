#!/usr/bin/env zsh
# bot.zsh — entrypoint
set -o pipefail
cd "${0:A:h}"
source ./config.zsh
for f in lib/*.zsh handlers/*.zsh; source ./$f
_store_init
log_info "tg-modbot starting (poll timeout=${POLL_TIMEOUT}s)"

offset=0
trap 'log_info "shutting down"; exit 0' INT TERM

while true; do
  resp=$(tg_call getUpdates \
           -d "timeout=${POLL_TIMEOUT}" \
           -d "offset=${offset}" \
           --data-urlencode 'allowed_updates=["message","edited_message","callback_query","chat_member","chat_join_request"]') || { sleep 3; continue; }

  # Iterate updates as compact JSON lines
  echo "$resp" | jq -c '.result[]?' | while IFS= read -r upd; do
    offset=$(( $(print -r -- "$upd" | jq_get '.update_id') + 1 ))
    dispatch "$upd"
  done
done
