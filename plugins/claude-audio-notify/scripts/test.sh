#!/bin/bash
# Test script for claude-audio-notify
# Run: bash scripts/test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Claude Audio Notify Test ==="
echo ""

# Check audio players
echo "Checking audio players..."
players=("paplay" "pw-play" "aplay" "mpv" "ffplay" "afplay")
found_player=""
for player in "${players[@]}"; do
    if command -v "$player" &>/dev/null; then
        echo "  ✓ Found: $player"
        found_player="$player"
        break
    fi
done

if [[ -z "$found_player" ]]; then
    echo "  ✗ No audio player found!"
    echo "  Install one of: pulseaudio-utils, alsa-utils, mpv, ffmpeg"
fi
echo ""

# Check TTS
echo "Checking TTS engines..."
tts_engines=("say" "espeak-ng" "espeak" "spd-say" "festival")
found_tts=""
for engine in "${tts_engines[@]}"; do
    if command -v "$engine" &>/dev/null; then
        echo "  ✓ Found: $engine"
        found_tts="$engine"
        break
    fi
done

if [[ -z "$found_tts" ]]; then
    echo "  ✗ No TTS engine found (optional)"
    echo "  Install: espeak-ng or speech-dispatcher"
fi
echo ""

# Check config
echo "Checking configuration..."
config_path="$HOME/.config/claude-audio-notify/config.json"
if [[ -f "$config_path" ]]; then
    echo "  ✓ Config found: $config_path"
else
    echo "  ○ No user config (will use defaults)"
    echo "  Create: $config_path"
fi
echo ""

# Find sounds
echo "Checking sounds..."
sounds=("stop" "notification" "subagent")
for sound in "${sounds[@]}"; do
    # Check bundled
    if [[ -f "$PLUGIN_ROOT/sounds/${sound}.ogg" ]]; then
        echo "  ✓ $sound: bundled"
    # Check system
    elif [[ -f "/usr/share/sounds/freedesktop/stereo/complete.oga" ]]; then
        echo "  ○ $sound: will use system fallback"
    else
        echo "  ✗ $sound: no sound found"
    fi
done
echo ""

# Test sounds
echo "Testing sounds..."
read -p "Play test sound? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Testing 'stop' event..."
    echo '{}' | bash "$SCRIPT_DIR/notify.sh" stop
    echo "  Done!"
    echo ""
    
    if [[ -n "$found_tts" ]]; then
        read -p "Test TTS? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            case "$found_tts" in
                say) say "Claude audio notify is working" ;;
                espeak-ng) espeak-ng "Claude audio notify is working" ;;
                espeak) espeak "Claude audio notify is working" ;;
                spd-say) spd-say "Claude audio notify is working" ;;
                festival) echo "Claude audio notify is working" | festival --tts ;;
            esac
        fi
    fi
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To install globally:"
echo "  claude plugin install $PLUGIN_ROOT --scope user"
echo ""
echo "To test without installing:"
echo "  claude --plugin-dir $PLUGIN_ROOT"
