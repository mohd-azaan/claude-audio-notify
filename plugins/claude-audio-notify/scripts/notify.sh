#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIG_PATHS=(
    "$HOME/.config/claude-audio-notify/config.json"
    "$PLUGIN_ROOT/config.json"
)

get_config() {
    local key="$1"
    local default="${2:-}"
    for config_path in "${CONFIG_PATHS[@]}"; do
        if [[ -f "$config_path" ]]; then
            local value
            value=$(jq -r ".$key // empty" "$config_path" 2>/dev/null || echo "")
            if [[ -n "$value" && "$value" != "null" ]]; then
                echo "$value"
                return
            fi
        fi
    done
    echo "$default"
}

get_event_config() {
    local event="$1"
    local key="$2"
    local default="${3:-}"
    for config_path in "${CONFIG_PATHS[@]}"; do
        if [[ -f "$config_path" ]]; then
            local value
            value=$(jq -r ".events.$event.$key // empty" "$config_path" 2>/dev/null || echo "")
            if [[ -n "$value" && "$value" != "null" ]]; then
                echo "$value"
                return
            fi
        fi
    done
    echo "$default"
}

play_sound() {
    local sound_file="$1"
    [[ ! -f "$sound_file" ]] && return 1
    
    if command -v pw-play &>/dev/null; then
        pw-play "$sound_file" &
    elif command -v paplay &>/dev/null; then
        paplay "$sound_file" &
    elif command -v aplay &>/dev/null; then
        aplay -q "$sound_file" &
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        afplay "$sound_file" &
    fi
}

speak() {
    local message="$1"
    local pitch
    pitch=$(get_config "tts_pitch" "0")
    
    if command -v spd-say &>/dev/null; then
        spd-say -p "$pitch" "$message" &
    elif command -v espeak-ng &>/dev/null; then
        espeak-ng "$message" &
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        say "$message" &
    fi
}

handle_event() {
    local event="$1"
    
    local enabled
    enabled=$(get_config "enabled" "true")
    [[ "$enabled" != "true" ]] && return 0
    
    local event_enabled
    event_enabled=$(get_event_config "$event" "enabled" "true")
    [[ "$event_enabled" != "true" ]] && return 0
    
    # Play sound (if not "none")
    local sound_path
    sound_path=$(get_event_config "$event" "sound" "")
    if [[ -n "$sound_path" && "$sound_path" != "none" && -f "$sound_path" ]]; then
        play_sound "$sound_path"
    fi
    
    # TTS
    local tts_enabled
    tts_enabled=$(get_event_config "$event" "tts" "false")
    if [[ "$tts_enabled" == "true" ]]; then
        local tts_message
        tts_message=$(get_event_config "$event" "tts_message" "Notification")
        speak "$tts_message"
    fi
}

# Read stdin and discard
cat > /dev/null 2>&1 || true

event="${1:-}"
case "$event" in
    stop|notification|subagent|session_start)
        handle_event "$event"
        ;;
esac
