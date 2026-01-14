# claude-audio-notify

Audio notifications for Claude Code. Get sounds when:
- **Stop**: Claude finishes responding
- **Notification**: Claude needs your input (permissions, questions, idle)
- **SubagentStop**: Subagent tasks complete
- **SessionStart**: New session begins (optional)

## Installation

### Option 1: Direct install from GitHub
```bash
claude plugin install https://github.com/YOUR_USERNAME/claude-audio-notify --scope user
```

### Option 2: Local development install
```bash
# Clone/download to any location
git clone https://github.com/YOUR_USERNAME/claude-audio-notify.git ~/claude-audio-notify

# Install from local path
claude plugin install ~/claude-audio-notify --scope user

# Or test without installing
claude --plugin-dir ~/claude-audio-notify
```

## Configuration

Create `~/.config/claude-audio-notify/config.json`:

```json
{
  "enabled": true,
  "cooldown": 2,
  
  "events": {
    "stop": {
      "enabled": true,
      "sound": "~/my-sounds/complete.ogg",
      "min_duration": 5,
      "tts": false,
      "tts_message": "Task complete"
    },
    "notification": {
      "enabled": true,
      "sound": "~/my-sounds/alert.ogg",
      "tts": true,
      "tts_message": "Claude needs your input"
    },
    "subagent": {
      "enabled": true,
      "tts": false
    },
    "session_start": {
      "enabled": false
    }
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `true` | Master on/off switch |
| `cooldown` | int | `2` | Seconds between sounds (prevents spam) |

### Per-Event Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `true` | Enable this event |
| `sound` | string | auto | Path to custom sound file |
| `min_duration` | int | `0` | Min task duration before playing (stop only) |
| `tts` | bool | `false` | Enable text-to-speech |
| `tts_message` | string | auto | Custom TTS message |

## Sound File Resolution

The plugin looks for sounds in this order:

1. **Custom path** from config (`sound` option)
2. **Bundled sounds** in `sounds/` directory
3. **System sounds** (freedesktop, GNOME, macOS)

### Supported Formats
- `.ogg`, `.oga` (Linux)
- `.wav` (Universal)
- `.aiff` (macOS)
- `.mp3` (if mpv/ffplay available)

### Supported Players (auto-detected)
- **macOS**: `afplay`
- **Linux**: `paplay` (PulseAudio), `pw-play` (PipeWire), `aplay` (ALSA), `mpv`, `ffplay`

### TTS Engines (auto-detected)
- **macOS**: `say`
- **Linux**: `espeak-ng`, `espeak`, `spd-say`, `festival`

## Examples

### Minimal - Just sounds, no TTS
```json
{
  "enabled": true,
  "events": {
    "stop": { "enabled": true },
    "notification": { "enabled": true }
  }
}
```

### TTS for notifications only
```json
{
  "enabled": true,
  "events": {
    "stop": { "enabled": true, "tts": false },
    "notification": { 
      "enabled": true, 
      "tts": true,
      "tts_message": "Hey! Claude needs you"
    }
  }
}
```

### Skip short tasks
```json
{
  "events": {
    "stop": { 
      "enabled": true, 
      "min_duration": 10
    }
  }
}
```

### Custom sounds everywhere
```json
{
  "events": {
    "stop": { "sound": "~/sounds/mario-complete.ogg" },
    "notification": { "sound": "~/sounds/alert.wav" },
    "subagent": { "sound": "~/sounds/subtle-ping.ogg" }
  }
}
```

## Troubleshooting

### No sound playing
1. Check audio player: `paplay --version` or `afplay` on macOS
2. Test manually: `paplay /usr/share/sounds/freedesktop/stereo/complete.oga`
3. Check config path: `~/.config/claude-audio-notify/config.json`

### Sound plays too often
Increase cooldown:
```json
{ "cooldown": 5 }
```

### Sound on short tasks is annoying
Set minimum duration:
```json
{ "events": { "stop": { "min_duration": 10 } } }
```

### Check loaded hooks
In Claude Code:
```
/hooks
```

## License

MIT
