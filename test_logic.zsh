#!/usr/bin/env zsh
# test_logic.zsh

source ./config.zsh
source ./lib/json.zsh
source ./lib/log.zsh
source ./lib/store.zsh
source ./lib/perms.zsh
source ./handlers/commands.zsh
source ./handlers/filters.zsh

# Mock tg_call
tg_call() {
    echo "{\"ok\":true,\"result\":{}}"
}

# Mock log_warn to not pollute test output
log_warn() { :; }
log_info() { :; }

test_json_str() {
    local res=$(json_str "hello \"world\"")
    [[ "$res" == "\"hello \\\"world\\\"\"" ]] || { echo "json_str failed: $res"; return 1; }
    echo "test_json_str passed"
}

test_parse_duration() {
    [[ $(parse_duration 10) == 600 ]] || return 1
    [[ $(parse_duration 10s) == 10 ]] || return 1
    [[ $(parse_duration 1m) == 60 ]] || return 1
    [[ $(parse_duration 1h) == 3600 ]] || return 1
    [[ $(parse_duration 1d) == 86400 ]] || return 1
    echo "test_parse_duration passed"
}

test_is_owner() {
    is_owner 11111111 || return 1
    is_owner 22222222 || return 1
    is_owner 33333333 && return 1
    echo "test_is_owner passed"
}

test_store() {
    export DATA_DIR=$(mktemp -d)
    _store_init
    warn_add "chat1" "user1" > /dev/null
    [[ $(warn_count "chat1" "user1") == 1 ]] || return 1
    warn_add "chat1" "user1" > /dev/null
    [[ $(warn_count "chat1" "user1") == 2 ]] || return 1
    warn_reset "chat1" "user1"
    [[ $(warn_count "chat1" "user1") == 0 ]] || return 1

    setting_set "chat1" "welcome" "Hello %NAME%"
    [[ $(setting_get "chat1" "welcome") == "Hello %NAME%" ]] || return 1
    echo "test_store passed"
}

test_html_esc() {
    [[ $(html_esc "A & B < C > D") == "A &amp; B &lt; C &gt; D" ]] || return 1
    echo "test_html_esc passed"
}

test_json_str
test_parse_duration
test_is_owner
test_store
test_html_esc
