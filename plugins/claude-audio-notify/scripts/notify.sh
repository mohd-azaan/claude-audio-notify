#!/bin/bash
# claude-audio-notify - Main notification dispatcher
# Usage: notify.sh <event_type>
# Events: stop, notification, subagent, session_start

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Config locations (checked in order)
CONFIG_PATHS=(
    "$HOME/.config/claude-audio-notify/config.json"
    "$PLUGIN_ROOT/config.json"
)

# Defaults
DEFAULT_ENABLED=true
DEFAULT_TTS_ENABLED=false
DEFAULT_MIN_DURATION=0
DEFAULT_COOLDOWN=2

# State file for cooldown/duration tracking
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-audio-notify"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/state.json"

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"last_sound_time":0,"session_start_time":0}' > "$STATE_FILE"
fi

# --- Utility Functions ---

log() {
    echo "[claude-audio-notify] $*" >&2
}

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

get_timestamp() {
    date +%s
}

update_state() {
    local key="$1"
    local value="$2"
    
    if [[ -f "$STATE_FILE" ]]; then
        local tmp
        tmp=$(mktemp)
        jq ".$key = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi
}

get_state() {
    local key="$1"
    local default="${2:-0}"
    
    if [[ -f "$STATE_FILE" ]]; then
        jq -r ".$key // $default" "$STATE_FILE" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# --- Sound Playback ---

play_sound() {
    local sound_file="$1"
    
    # Check if file exists
    if [[ ! -f "$sound_file" ]]; then
        log "Sound file not found: $sound_file"
        return 1
    fi
    
    # Detect OS and play
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        afplay "$sound_file" &
    elif command -v paplay &>/dev/null; then
        # Linux with PulseAudio
        paplay "$sound_file" &
    elif command -v pw-play &>/dev/null; then
        # Linux with PipeWire
        pw-play "$sound_file" &
    elif command -v aplay &>/dev/null; then
        # Linux with ALSA
        aplay -q "$sound_file" &
    elif command -v mpv &>/dev/null; then
        mpv --no-video --really-quiet "$sound_file" &
    elif command -v ffplay &>/dev/null; then
        ffplay -nodisp -autoexit -loglevel quiet "$sound_file" &
    else
        log "No audio player found"
        return 1
    fi
}

resolve_sound_file() {
    local event="$1"
    
    # Priority: custom path > bundled > system
    local custom_path
    custom_path=$(get_event_config "$event" "sound" "")
    
    if [[ -n "$custom_path" && -f "$custom_path" ]]; then
        echo "$custom_path"
        return
    fi
    
    # Expand ~ in path
    if [[ -n "$custom_path" && "$custom_path" == ~* ]]; then
        local expanded="${custom_path/#\~/$HOME}"
        if [[ -f "$expanded" ]]; then
            echo "$expanded"
            return
        fi
    fi
    
    # Bundled sounds
    local bundled="$PLUGIN_ROOT/sounds/${event}.ogg"
    if [[ -f "$bundled" ]]; then
        echo "$bundled"
        return
    fi
    
    # System sounds fallback
    local system_sounds=(
        "/usr/share/sounds/freedesktop/stereo/complete.oga"
        "/usr/share/sounds/freedesktop/stereo/message.oga"
        "/usr/share/sounds/gnome/default/alerts/drip.ogg"
        "/System/Library/Sounds/Glass.aiff"
        "/System/Library/Sounds/Ping.aiff"
    )
    
    for sys_sound in "${system_sounds[@]}"; do
        if [[ -f "$sys_sound" ]]; then
            echo "$sys_sound"
            return
        fi
    done
    
    log "No sound file found for event: $event"
    return 1
}

# --- TTS ---

speak() {
    local message="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        say "$message" &
    elif command -v espeak-ng &>/dev/null; then
        espeak-ng "$message" &
    elif command -v espeak &>/dev/null; then
        espeak "$message" &
    elif command -v spd-say &>/dev/null; then
        spd-say -p $(get_config "tts_pitch" "0") "$message" &
    elif command -v festival &>/dev/null; then
        echo "$message" | festival --tts &
    else
        log "No TTS engine found"
        return 1
    fi
}

# --- Event Handlers ---

handle_event() {
    local event="$1"
    local now
    now=$(get_timestamp)
    
    # Check if globally enabled
    local enabled
    enabled=$(get_config "enabled" "$DEFAULT_ENABLED")
    if [[ "$enabled" != "true" ]]; then
        return 0
    fi
    
    # Check if this specific event is enabled
    local event_enabled
    event_enabled=$(get_event_config "$event" "enabled" "true")
    if [[ "$event_enabled" != "true" ]]; then
        return 0
    fi
    
    # Check cooldown
    local cooldown
    cooldown=$(get_config "cooldown" "$DEFAULT_COOLDOWN")
    local last_sound_time
    last_sound_time=$(get_state "last_sound_time" "0")
    
    if (( now - last_sound_time < cooldown )); then
        log "Cooldown active, skipping sound"
        return 0
    fi
    
    # Check minimum duration (for Stop event)
    if [[ "$event" == "stop" ]]; then
        local min_duration
        min_duration=$(get_event_config "stop" "min_duration" "$DEFAULT_MIN_DURATION")
        local session_start
        session_start=$(get_state "session_start_time" "0")
        
        if (( session_start > 0 && now - session_start < min_duration )); then
            log "Task too short (< ${min_duration}s), skipping sound"
            return 0
        fi
    fi
    
    # Play sound
    local sound_file
    if sound_file=$(resolve_sound_file "$event"); then
        play_sound "$sound_file"
        update_state "last_sound_time" "$now"
    fi
    
    # TTS if enabled
    local tts_enabled
    tts_enabled=$(get_event_config "$event" "tts" "false")
    if [[ "$tts_enabled" == "true" ]]; then
        local tts_message
        tts_message=$(get_event_config "$event" "tts_message" "")
        
        if [[ -z "$tts_message" ]]; then
            case "$event" in
                stop) tts_message="Task complete" ;;
                notification) tts_message="Claude needs your input" ;;
                subagent) tts_message="Subagent finished" ;;
                *) tts_message="Claude notification" ;;
            esac
        fi
        
        speak "$tts_message"
    fi
}

handle_session_start() {
    local now
    now=$(get_timestamp)
    update_state "session_start_time" "$now"
    
    # Optional startup sound
    local startup_sound
    startup_sound=$(get_event_config "session_start" "enabled" "false")
    if [[ "$startup_sound" == "true" ]]; then
        handle_event "session_start"
    fi
}

# --- Main ---

main() {
    local event="${1:-}"
    
    if [[ -z "$event" ]]; then
        log "Usage: notify.sh <event_type>"
        log "Events: stop, notification, subagent, session_start"
        exit 1
    fi
    
    # Read stdin (hook input JSON) but we don't need it for basic notifications
    # Could be extended to extract more context (e.g., notification type)
    cat > /dev/null 2>&1 || true
    
    case "$event" in
        stop|notification|subagent)
            handle_event "$event"
            ;;
        session_start)
            handle_session_start
            ;;
        *)
            log "Unknown event: $event"
            exit 1
            ;;
    esac
}

main "$@"
