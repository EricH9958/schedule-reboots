#!/usr/bin/env bash
set -u

TAUTULLI_URL="http://media-monitor.example.lan:8181"
TAUTULLI_API_KEY="REPLACE_WITH_TAUTULLI_API_KEY"

MODE=""
TARGET_USER=""
MESSAGE="Server maintenance in progress. Playback has been stopped."

usage() {
    echo "Usage:"
    echo "  $0 --all [--message 'text']"
    echo "  $0 --user username [--message 'text']"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --all)
            MODE="all"
            shift
            ;;
        --user)
            MODE="user"
            TARGET_USER="$2"
            shift 2
            ;;
        --message)
            MESSAGE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -z "$MODE" ] && usage
[ "$MODE" = "user" ] && [ -z "$TARGET_USER" ] && usage

api_get() {
    curl -fsS --get \
        --data-urlencode "apikey=${TAUTULLI_API_KEY}" \
        --data-urlencode "cmd=$1" \
        "${TAUTULLI_URL}/api/v2"
}

get_session_ids() {
    if [ "$MODE" = "all" ]; then
        api_get get_activity | jq -r '.response.data.sessions[]?.session_id'
    else
        api_get get_activity | jq -r --arg u "$TARGET_USER" \
            '.response.data.sessions[]? | select(.username == $u or .user == $u) | .session_id'
    fi
}

kill_sessions() {
    local found=0
    local session_id

    while IFS= read -r session_id; do
        [ -z "$session_id" ] && continue
        found=1

        curl -fsS --get \
            --data-urlencode "apikey=${TAUTULLI_API_KEY}" \
            --data-urlencode "cmd=terminate_session" \
            --data-urlencode "session_id=${session_id}" \
            --data-urlencode "message=${MESSAGE}" \
            "${TAUTULLI_URL}/api/v2" >/dev/null
    done

    return 0
}

get_session_ids | kill_sessions
