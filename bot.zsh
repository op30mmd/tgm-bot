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

  # Extract the update ID and compact JSON string on a single line to avoid forks inside the loop
  print -r -- "$resp" | jq -r '.result[]? | "\(.update_id) \(@json)"' | while read -r up_id raw_upd; do
    [[ -z $up_id ]] && continue
    offset=$(( up_id + 1 ))
    dispatch "$raw_upd"
  done
done
