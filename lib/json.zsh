# lib/json.zsh

# JSON-escape an arbitrary string using jq (handles quotes, newlines, unicode).
json_str() { jq -Rn --arg v "$1" '$v'; }

# Extract a field from a JSON blob on stdin: jq_get '.message.text'
jq_get() { jq -r "${1} // empty"; }

# HTML-escape a string for Telegram's HTML parse_mode
html_esc() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  print -r -- "$s"
}

# Build a ChatPermissions object. Pass 1 to allow everything, 0 to mute.
perms_json() {
  local v=$1
  local b=$([[ $v == 1 ]] && print -r -- true || print -r -- false)
  cat <<EOF
{"can_send_messages":$b,"can_send_audios":$b,"can_send_documents":$b,"can_send_photos":$b,"can_send_videos":$b,"can_send_video_notes":$b,"can_send_voice_notes":$b,"can_send_polls":$b,"can_send_other_messages":$b,"can_add_web_page_previews":$b}
EOF
}
