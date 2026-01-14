# Sound Files

Place your custom sounds here. Expected filenames:

- `stop.ogg` - Played when Claude finishes
- `notification.ogg` - Played when Claude needs input  
- `subagent.ogg` - Played when subagent finishes
- `session_start.ogg` - Played on new session (if enabled)

## Free Sound Sources

- [Freesound.org](https://freesound.org/) - CC licensed sounds
- [Mixkit](https://mixkit.co/free-sound-effects/) - Free sound effects
- [Notification Sounds](https://notificationsounds.com/) - Mobile notification sounds

## Quick Setup (Linux)

Copy system sounds:
```bash
cp /usr/share/sounds/freedesktop/stereo/complete.oga sounds/stop.ogg
cp /usr/share/sounds/freedesktop/stereo/message.oga sounds/notification.ogg
cp /usr/share/sounds/freedesktop/stereo/bell.oga sounds/subagent.ogg
```

## Recommended: Short, Distinct Sounds

- **stop**: Triumphant chime (0.5-1s)
- **notification**: Alert/attention grabber (0.3-0.5s)  
- **subagent**: Subtle ping (0.2-0.4s)
