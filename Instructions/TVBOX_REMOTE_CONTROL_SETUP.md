# TV Box Remote Control Setup (Oracle VM → Android TV Box)

Control an Android TV box from a remote Linux server (Oracle Cloud) via ADB + scrcpy-mcp, with an auto-establishing reverse SSH tunnel.

---

## Device Info

- **TV Box**: X88 Pro 13 (RK3528, Android TV 13, 4GB RAM, 32GB ROM)
- **Root**: Stock root (pre-rooted firmware, `su 0` works, SELinux permissive)
- **Oracle VM**: ARM64 (Ampere A1), Ubuntu, public IP `132.145.163.128`, SSH alias `claudeclaw`
- **ADB port**: 5555 (auto-enabled on boot via init script)
- **Tunnel port**: 15555 on Oracle VM → localhost:5555 on TV box

---

## What's Already Done

### On the TV Box

1. **ADB over TCP** auto-enables on boot via init script (`setprop service.adb.tcp.port 5555 && stop adbd && start adbd`)

2. **Termux** installed (v0.118.3) with openssh package

3. **SSH tunnel key** generated at `/data/local/ssh/id_tunnel` (ed25519)

4. **SSH binaries** copied to `/data/local/ssh/ssh` and `/data/local/ssh/ssh-keygen` (from Termux's OpenSSH 10.2p1)

5. **Tunnel script** at `/data/local/ssh/tunnel.sh`:
   - Waits for network
   - Force-enables ADB TCP on port 5555
   - Connects to Oracle VM as `tunnel@132.145.163.128`
   - Creates reverse tunnel: `-R 15555:localhost:5555`
   - Auto-reconnects on disconnect (while loop with 15s sleep)

6. **Init service** at `/system/etc/init/ssh_tunnel.rc`:
   - Triggers on `sys.boot_completed=1`
   - Runs `/data/local/ssh/tunnel.sh` as root
   - Auto-starts on every boot

7. **Debloated**: 21 bloatware packages removed via `pm uninstall -k --user 0`

8. **Tasker**: Installed with MCP profile, but HTTP Request event is broken on Android TV 13 (returns 503). Not usable for remote control. Use scrcpy-mcp instead.

### On the Oracle VM

1. **Tunnel user** created: `tunnel` (shell `/bin/false`, SSH key-only, restricted to port forwarding)

2. **ADB** installed via `apt` (android-tools-adb)

3. **Bash aliases** in `~/.bashrc`:
   ```bash
   alias tvbox="adb -s localhost:15555"
   alias tvbox-connect="adb connect localhost:15555"
   alias tvbox-screenshot="adb -s localhost:15555 exec-out screencap -p > /tmp/tvbox.png"
   ```

4. **Tunnel auto-establishes**: TV box connects to Oracle VM on boot, port 15555 becomes available

---

## What Still Needs to Be Done (Oracle VM Side)

### 1. Install scrcpy-mcp

scrcpy-mcp is a Python MCP server that exposes 22 ADB/scrcpy tools for Claude Code.

```bash
# Clone the repo
cd ~/agent-repos  # or wherever you keep repos
git clone https://github.com/charettep/scrcpy-mcp.git
cd scrcpy-mcp

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create venv and install dependencies
uv venv .venv
uv pip install -r requirements.txt

# Verify it works
.venv/bin/python scrcpy_mcp.py  # Should start on stdio, Ctrl+C to stop
```

### 2. Install scrcpy (needed for mirroring/recording, optional for basic control)

```bash
sudo apt install scrcpy
# If not available in apt:
# snap install scrcpy
```

Note: scrcpy is only needed for `start_mirror` and `screen_record` tools. All other tools (screenshot, tap, swipe, input, app management) work with just ADB.

### 3. Install mcp2cli (optional — for CLI usage)

mcp2cli lets you use scrcpy-mcp as a command-line tool without Claude Code.

```bash
# Install
uv tool install mcp2cli

# Bake a shortcut for the TV box
mcp2cli bake create tvbox --mcp-stdio "$HOME/agent-repos/scrcpy-mcp/.venv/bin/python $HOME/agent-repos/scrcpy-mcp/scrcpy_mcp.py"

# Usage examples:
mcp2cli @tvbox --list                                    # List all tools
mcp2cli @tvbox screenshot --output-path /tmp/tv.png      # Screenshot
mcp2cli @tvbox device-info --serial localhost:15555       # Device info
mcp2cli @tvbox tap --x 500 --y 500 --serial localhost:15555  # Tap
mcp2cli @tvbox key-event --key HOME --serial localhost:15555  # Press HOME
mcp2cli @tvbox input-text --text "hello" --serial localhost:15555  # Type text
mcp2cli @tvbox start-app --package com.google.android.youtube.tv --serial localhost:15555  # Open YouTube
```

### 4. Register scrcpy-mcp as MCP Server in Claude Code

Add to `~/.claude.json` (or project-level config):

```json
{
  "mcpServers": {
    "scrcpy-tvbox": {
      "command": "/home/ubuntu/agent-repos/scrcpy-mcp/.venv/bin/python",
      "args": ["/home/ubuntu/agent-repos/scrcpy-mcp/scrcpy_mcp.py"],
      "env": {}
    }
  }
}
```

Or via CLI:
```bash
claude mcp add scrcpy-tvbox -- /home/ubuntu/agent-repos/scrcpy-mcp/.venv/bin/python /home/ubuntu/agent-repos/scrcpy-mcp/scrcpy_mcp.py
```

When calling tools, always pass `--serial localhost:15555` (or `serial="localhost:15555"` in MCP) to target the TV box through the tunnel.

### 5. Auto-connect ADB on Tunnel Up (optional)

Create a systemd service that waits for the tunnel and connects ADB:

```bash
sudo tee /etc/systemd/system/adb-tvbox.service << 'EOF'
[Unit]
Description=ADB connection to TV box via reverse tunnel
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/bash -c 'until ss -tln | grep -q 15555; do sleep 5; done'
ExecStart=/usr/bin/adb connect localhost:15555
ExecStop=/usr/bin/adb disconnect localhost:15555
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable adb-tvbox
sudo systemctl start adb-tvbox
```

---

## Available scrcpy-mcp Tools (22)

### Device Management
| Tool | Description |
|------|-------------|
| `list_devices` | List connected devices |
| `device_info` | Model, Android version, screen res, battery, IP |
| `tcpip_connect` | Connect/disconnect wireless ADB |

### Input Injection
| Tool | Description |
|------|-------------|
| `tap` | Tap at x,y coordinates |
| `swipe` | Swipe from point A to B |
| `key_event` | BACK, HOME, POWER, ENTER, etc. |
| `input_text` | Type text string |
| `long_press` | Long press at coordinates |

### Screen & Display
| Tool | Description |
|------|-------------|
| `screenshot` | Capture and save screenshot |
| `screen_power` | Turn screen on/off/toggle |
| `rotation` | Get/set rotation |
| `screen_record` | Record screen to mp4 |

### App Management
| Tool | Description |
|------|-------------|
| `list_apps` | List installed packages |
| `start_app` | Launch app by package name |
| `stop_app` | Force stop app |
| `install_apk` | Install APK file |

### Clipboard
| Tool | Description |
|------|-------------|
| `get_clipboard` | Read device clipboard |
| `set_clipboard` | Set device clipboard |

### File Transfer
| Tool | Description |
|------|-------------|
| `push_file` | Push file to device |
| `pull_file` | Pull file from device |

### Scrcpy Sessions
| Tool | Description |
|------|-------------|
| `start_mirror` | Start scrcpy mirroring |
| `stop_session` | Stop scrcpy session |

---

## Useful ADB Commands (Direct)

These can be run via `tvbox shell <command>` alias or `adb -s localhost:15555 shell`:

```bash
# Volume control
cmd media_session volume --stream 3 --set 10    # Set media volume (0-15)
cmd media_session volume --stream 3 --get        # Get current volume

# Open YouTube and search
am start -a android.intent.action.VIEW -d "https://www.youtube.com/results?search_query=relaxing+music"

# Open SmartTube (ad-free YouTube)
am start -n com.liskovsoft.smarttubetv.beta/.ui.startup.SplashActivity

# Open Stremio
am start -n com.stremio.one/.MainActivity

# List running apps
dumpsys activity recents | grep "Recent #"

# Get screen state
dumpsys power | grep "Display Power"
```

---

## Installed Apps on TV Box

| App | Package |
|-----|---------|
| SmartTube (YouTube) | `org.smarttube.stable` |
| YouTube TV | `com.google.android.youtube.tv` |
| Netflix | `com.netflix.ninja` |
| Disney+ | `com.disney.disneyplus` |
| Stremio | `com.stremio.one` |
| Kiwi Browser | `com.kiwibrowser.browser` |
| Solid Explorer | `pl.solidexplorer2` |
| Moonlight | `com.limelight` |
| Tasker | `net.dinglisch.android.taskerm` |
| AutoInput | `com.joaomgcd.autoinput` |
| Termux | `com.termux` |

---

## Troubleshooting

### Tunnel not connecting after reboot
```bash
# On Oracle VM: check if port 15555 is listening
ss -tlnp | grep 15555

# If not, the TV box init script may not have run
# Check tunnel log (via direct ADB if on same LAN):
adb connect <TVBOX_LAN_IP>:5555
adb shell cat /data/local/ssh/tunnel.log
```

### ADB shows "device offline"
```bash
# Disconnect and reconnect
adb disconnect localhost:15555
sleep 2
adb connect localhost:15555
```

### ADB port 5555 not listening on TV box
The init script runs `setprop service.adb.tcp.port 5555 && stop adbd && start adbd`. If this fails:
```bash
# Manually enable from ADB shell (if you have LAN access):
adb shell su 0 setprop service.adb.tcp.port 5555
adb shell su 0 stop adbd
adb shell su 0 start adbd
```

### TV box IP changed (DHCP)
Doesn't matter — the TV box initiates the outbound SSH tunnel, so its LAN IP is irrelevant. The Oracle VM always accesses it via `localhost:15555`.

---

## Security Notes

- Tunnel user (`tunnel`) has no shell access, restricted to port forwarding only
- Port 15555 is bound to `127.0.0.1` on Oracle VM (not publicly accessible)
- SSH key auth only, no passwords
- ADB on the TV box accepts any local connection — this is secured by the SSH tunnel encryption

---

## Termux API (via ADB)

Termux API commands can be run from the Oracle VM through ADB using a helper script at `/data/local/ssh/termux-run.sh`:

```bash
# IMPORTANT: First wake up the Termux:API app silently (no UI, no app switching):
adb -s localhost:15555 shell "am broadcast -a com.termux.api.ACTION_WAKE_UP -n com.termux.api/.TermuxApiReceiver"
sleep 2

# Then run commands via: run-as com.termux /data/local/ssh/termux-run.sh <command> [args]
adb -s localhost:15555 shell "run-as com.termux /data/local/ssh/termux-run.sh termux-battery-status"
adb -s localhost:15555 shell "run-as com.termux /data/local/ssh/termux-run.sh termux-wifi-connectioninfo"
adb -s localhost:15555 shell "run-as com.termux /data/local/ssh/termux-run.sh termux-tts-speak hello"
adb -s localhost:15555 shell "run-as com.termux /data/local/ssh/termux-run.sh termux-notification --title Hi --content Hello"
```

> **If Termux API commands hang or timeout**, the API app was killed by Android. Re-send the wake-up broadcast above. This starts the API service silently in the background without opening any visible app or interrupting what's on screen.

### What works on Android TV

| Command | Status | Notes |
|---------|--------|-------|
| `termux-battery-status` | ✅ | Returns JSON (TV box has no battery, values are 0) |
| `termux-wifi-connectioninfo` | ✅ | Returns SSID, IP, signal strength, etc. |
| `termux-tts-speak` | ✅ | Text-to-speech through TV speakers (needs speaker connected) |
| `termux-notification` | ✅ | Android TV notifications |
| `termux-wifi-scaninfo` | ✅ | Scan nearby WiFi networks |
| `termux-toast` | ❌ | Android TV doesn't show toasts from background apps |
| `termux-clipboard-set/get` | ❌ | Returns empty on Android TV |

### Setup already done

- Termux + Termux:API + openssh installed
- All runtime permissions granted to `com.termux.api` via `pm grant`
- Special permissions (SYSTEM_ALERT_WINDOW, WRITE_SETTINGS, MANAGE_EXTERNAL_STORAGE) granted via `appops`
- Termux whitelisted from battery optimization
- Wake lock acquired via `termux-wake-lock`
- Helper script at `/data/local/ssh/termux-run.sh` sets up PATH and LD_LIBRARY_PATH for Termux binaries
- Termux sshd auto-starts on boot via the tunnel init script
- Reverse tunnel also forwards Termux SSH: port 18022 on Oracle VM → port 8022 on TV box

### Direct Termux SSH (alternative to ADB run-as)

For more complex Termux operations, SSH directly into Termux:

```bash
# From Oracle VM (SSH config alias already set up):
ssh tvbox-termux "termux-battery-status"
ssh tvbox-termux "termux-wifi-connectioninfo"
ssh tvbox-termux "pkg list-installed"
```

This gives a full Termux shell with all packages and environment available.

---

## Quick Reference: AI Assistant Media Playback

| Content | App | Display Offset | Command |
|---------|-----|---------------|---------|
| **Movies/Shows** (right-aligned) | mpv via Stremio | ✅ `video-align-x=1` | Search Cinemeta API → get stream from Torrentio → play in mpv |
| **Movies/Shows** (smooth, centered) | Stremio built-in | ❌ centered | Deep link: `stremio:///detail/movie/{imdb_id}/{imdb_id}` → press OK |
| **YouTube** (right-aligned) | mpv | ✅ `video-align-x=1` | `am start -d "URL" -n is.xyz.mpv/.MPVActivity` |
| **YouTube** (smooth, centered) | SmartTube | ❌ centered | `am start -d "https://youtube.com/watch?v=ID" -n org.smarttube.stable/...SplashActivity` |

> **Right-aligned (mpv)**: Uses software decoding (`hwdec=no`) — slightly less smooth but video avoids dead TV zone.
> **Centered (native apps)**: Uses hardware decoding — smooth but left ~25% of content is in the dead zone.
> The AI assistant should ask the user which mode they prefer, or default to mpv for the best viewing experience.

### YouTube

**Do NOT use Stremio for YouTube** — its search only finds movies/shows, not YouTube videos. Use **SmartTube** for YouTube:

```bash
# Search YouTube (opens SmartTube with results)
adb shell am start -a android.intent.action.VIEW \
  -d "https://www.youtube.com/results?search_query=QUERY+HERE" \
  -n org.smarttube.stable/com.liskovsoft.smartyoutubetv2.tv.ui.main.SplashActivity

# Play specific video
adb shell am start -a android.intent.action.VIEW \
  -d "https://www.youtube.com/watch?v=VIDEO_ID" \
  -n org.smarttube.stable/com.liskovsoft.smartyoutubetv2.tv.ui.main.SplashActivity

# For right-aligned playback, route through mpv instead:
adb shell am start -a android.intent.action.VIEW \
  -d "https://www.youtube.com/watch?v=VIDEO_ID" \
  -n is.xyz.mpv/.MPVActivity
```

The AI assistant can extract search results from SmartTube via UI snapshots (`uiautomator dump`) to find video titles and select content.

### Recommended Stremio Addons

| Addon | Content | Notes |
|-------|---------|-------|
| Cinemeta | Movie/show metadata | Built-in, required for search |
| Torrentio | Torrent streams | Enable Cinecalidad, set Latino priority |
| ~~YouTube / YouTubio~~ | ~~YouTube~~ | Don't use — Stremio can't search YouTube. Use SmartTube |
| Primer Latino | Latino movies/series | Paid (~$2.45/mo), español latino |
| Latino Movies | Spanish content | Free, dubbed/subtitled |
| Animeo | Anime | Integrates with Kitsu |
| TuSubtitulo | Spanish subtitles | es-ES, es-LA, catalán, English |
| AIOStreams | Aggregator with filtering | Regex/language filters for Latino |
| MediaFusion | Alternative indexer | Additional torrent sources |

---

## Stremio Control (Movies/Shows — Best for AI Assistant)

Stremio supports deep links and has a queryable addon API, making it ideal for programmatic control.

**Package**: `com.stremio.one` (v1.9.12)

### Search for content (no UI needed)

```bash
# Search movies via Cinemeta addon
curl -s "https://v3-cinemeta.strem.io/catalog/movie/top/search=inception.json" | jq '.metas[:3]'

# Search TV series
curl -s "https://v3-cinemeta.strem.io/catalog/series/top/search=breaking+bad.json" | jq '.metas[:3]'

# Get metadata for a specific title by IMDB ID
curl -s "https://v3-cinemeta.strem.io/meta/movie/tt1375666.json" | jq '.meta.name,.meta.year'

# Get available streams (from Torrentio or other stream addons)
curl -s "https://torrentio.strem.fun/stream/movie/tt1375666.json" | jq '.streams[:3]'
```

### Play content via deep links

```bash
# Open movie detail page
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "stremio:///detail/movie/tt1375666/tt1375666"

# Open TV series episode (series_imdb_id, season:episode)
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "stremio:///detail/series/tt0903747/tt0903747:1:1"

# Search inside Stremio
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "stremio:///search?search=inception"

# Open library
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "stremio:///library"

# After detail page loads, press OK to start playback
sleep 3
adb -s localhost:15555 shell input keyevent 23  # DPAD_CENTER
```

### Playback control

```bash
adb shell input keyevent 85   # MEDIA_PLAY_PAUSE
adb shell input keyevent 86   # MEDIA_STOP
adb shell input keyevent 90   # MEDIA_FAST_FORWARD
adb shell input keyevent 89   # MEDIA_REWIND
adb shell input keyevent 87   # MEDIA_NEXT
adb shell input keyevent 88   # MEDIA_PREVIOUS
```

### AI Assistant Workflow

1. **Launch Stremio first** (required for streaming server on port 11470):
   ```bash
   adb -s localhost:15555 shell monkey -p com.stremio.one -c android.intent.category.LAUNCHER 1
   sleep 5
   ```
2. **Search**: Query Cinemeta API with `curl` to get IMDB ID — no UI needed
3. **Get stream**: Query addon API for torrent hash, build URL: `http://127.0.0.1:11470/{infoHash}/{fileIdx}`
4. **Play in mpv** (right-aligned for dead TV panel):
   ```bash
   adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
     -d "http://127.0.0.1:11470/HASH/INDEX" -n is.xyz.mpv/.MPVActivity
   ```
5. **Control**: Use media key events for play/pause/seek

> **Important:** Stremio must be running for torrent streams to work. The streaming server at `127.0.0.1:11470` resolves torrent hashes to HTTP streams. If mpv fails to play, launch Stremio first.

### Performance Notes

- mpv uses `hwdec=no` (software decoding) for the right-aligned display offset — this is slightly less smooth than hardware decoding on the RK3528
- Prefer **x264** streams over x265/HEVC (x264 is faster to software decode)
- 720p streams play smoother but may have fewer seeders
- For smooth playback without offset, use Stremio's built-in player (centered)

### stremio-mcp (Optional MCP Server)

There's an existing MCP server for Stremio control: `github.com/netixc/stremio-mcp`. It wraps TMDB search + Stremio deep links + ADB into MCP tools. Clone and install:

```bash
git clone https://github.com/netixc/stremio-mcp.git
cd stremio-mcp
# Follow setup instructions in README
```

---

## SmartTube (YouTube — Ad-Free)

**Package**: `org.smarttube.stable` (v31.30)

```bash
# Play a YouTube video
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "https://www.youtube.com/watch?v=VIDEO_ID" \
  -n org.smarttube.stable/com.liskovsoft.smartyoutubetv2.tv.ui.main.SplashActivity

# Launch SmartTube
adb -s localhost:15555 shell am start \
  -n org.smarttube.stable/com.liskovsoft.smartyoutubetv2.tv.ui.main.SplashActivity

# Playback control (same media key events as Stremio)
adb shell input keyevent 85   # MEDIA_PLAY_PAUSE
```

> **Note**: SmartTube Beta was removed due to "Cannot load content" errors. The stable version (`org.smarttube.stable`) works. If it breaks in the future, use the official YouTube TV app (`com.google.android.youtube.tv`) as fallback.

---

## LG TV Control (WebOS SSAP)

The LG TV (75UN8000PSB, WebOS) can be controlled via the SSAP WebSocket API from any device on the LAN. This allows switching inputs, controlling volume, turning the TV on/off, etc.

- **TV IP**: 192.168.100.13
- **SSAP Port**: 3001 (WSS)
- **Client Key**: `229c7620d58fbb8bbdf1d3d7b0f7a314` (persists across reboots)
- **TV Box Input**: HDMI_4

### Connection

The key to getting full permissions is registering with a **full manifest** that requests all permission scopes. Without the manifest, most commands return 401.

```python
import asyncio, json, ssl, websockets

TV_IP = "192.168.100.13"
CLIENT_KEY = "229c7620d58fbb8bbdf1d3d7b0f7a314"

# Full manifest for elevated permissions (required for TV control)
REGISTER_PAYLOAD = {
    "client-key": CLIENT_KEY,
    "manifest": {
        "manifestVersion": 1,
        "appVersion": "1.1",
        "signed": {
            "created": "20140509",
            "appId": "com.lge.test",
            "vendorId": "com.lge",
            "localizedAppNames": {"": "LG Remote"},
            "localizedVendorNames": {"": "LG Electronics"},
            "permissions": ["TEST_SECURE","TEST_PROTECTED","CONTROL_POWER","CONTROL_DISPLAY",
                "CONTROL_INPUT_JOYSTICK","CONTROL_INPUT_MEDIA_RECORDING",
                "CONTROL_INPUT_MEDIA_PLAYBACK","CONTROL_INPUT_TV",
                "CONTROL_MOUSE_AND_KEYBOARD","READ_APP_STATUS","READ_CURRENT_CHANNEL",
                "READ_INPUT_DEVICE_LIST","READ_NETWORK_STATE","READ_RUNNING_APPS",
                "READ_TV_CURRENT_TIME","READ_TV_CHANNEL_LIST","WRITE_NOTIFICATION_TOAST",
                "READ_POWER_STATE","READ_COUNTRY_INFO","READ_SETTINGS","CONTROL_TV_SCREEN",
                "CONTROL_TV_STANBY","CONTROL_FAVORITE_GROUP","CONTROL_USER_INFO",
                "CHECK_BLUETOOTH_DEVICE","CONTROL_BLUETOOTH","CONTROL_TIMER_INFO",
                "STB_INTERNAL_CONNECTION","CONTROL_RECORDING","READ_RECORDING_STATE",
                "WRITE_RECORDING_LIST","READ_RECORDING_LIST","READ_RECORDING_SCHEDULE",
                "WRITE_RECORDING_SCHEDULE","READ_STORAGE_DEVICE_LIST","READ_TV_PROGRAM_INFO",
                "CONTROL_BOX_CHANNEL","READ_TV_ACR","READ_TV_CONTENT_STATE",
                "CONTROL_CHANNEL_BLOCK","CONTROL_CHANNEL_GROUP","CONTROL_TV_POWER",
                "CREATE_CHANNEL_GROUP","CONTROL_INPUT_TEXT"],
            "serial": "serial1"
        },
        "permissions": ["LAUNCH","LAUNCH_WEBAPP","APP_TO_APP","CONTROL_AUDIO",
            "CONTROL_DISPLAY","CONTROL_INPUT_JOYSTICK","CONTROL_INPUT_MEDIA_PLAYBACK",
            "CONTROL_INPUT_MEDIA_RECORDING","CONTROL_INPUT_TV",
            "CONTROL_MOUSE_AND_KEYBOARD","CONTROL_POWER","READ_APP_STATUS",
            "READ_CURRENT_CHANNEL","READ_INPUT_DEVICE_LIST","READ_NETWORK_STATE",
            "READ_RUNNING_APPS","READ_TV_CHANNEL_LIST","READ_TV_CURRENT_TIME",
            "WRITE_NOTIFICATION_TOAST","CONTROL_TV_SCREEN","READ_SETTINGS","WRITE_SETTINGS"],
        "signatures": [{"signatureVersion":1,"signature":""}]
    }
}
```

> **Note**: If the client key stops working, register with an empty `client-key` in the payload above. The TV will show a pairing prompt — accept it to get a new key.

### Available SSAP Commands

| Command | URI | Payload |
|---------|-----|---------|
| Switch to TV box | `ssap://tv/switchInput` | `{"inputId": "HDMI_4"}` |
| Switch to Live TV | `ssap://system.launcher/launch` | `{"id": "com.webos.app.livetv"}` |
| Get volume | `ssap://audio/getVolume` | `{}` |
| Set volume | `ssap://audio/setVolume` | `{"volume": 15}` |
| Mute/unmute | `ssap://audio/setMute` | `{"mute": true}` |
| Turn off TV | `ssap://system/turnOff` | `{}` | **WARNING: Don't use — Dev Mode session expires on power off** |
| List inputs | `ssap://tv/getExternalInputList` | `{}` |
| Get foreground app | `ssap://com.webos.applicationManager/getForegroundAppInfo` | `{}` |
| Launch app | `ssap://system.launcher/launch` | `{"id": "com.webos.app.browser"}` |
| Show toast | `ssap://system.notifications/createToast` | `{"message": "Hello"}` |

### Quick CLI Usage

```bash
# One-liner to switch TV to TV box input
python -c "
import asyncio,json,ssl,websockets
async def f():
    s=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT);s.check_hostname=False;s.verify_mode=ssl.CERT_NONE
    w=await websockets.connect('wss://192.168.100.13:3001',ssl=s)
    await w.send(json.dumps({'type':'register','payload':{'client-key':'229c7620d58fbb8bbdf1d3d7b0f7a314'}}))
    await w.recv()
    await w.send(json.dumps({'id':'1','type':'request','uri':'ssap://tv/switchInput','payload':{'inputId':'HDMI_4'}}))
    print(await asyncio.wait_for(w.recv(),timeout=5))
asyncio.run(f())
"
```

### HDMI Inputs

| ID | Label | Status |
|----|-------|--------|
| HDMI_1 | HDMI 1 | Disconnected |
| HDMI_2 | HDMI 2 | Disconnected |
| HDMI_3 | HDMI 3 | Disconnected |
| HDMI_4 | HDMI 4 | **TV Box (connected)** |

### SSH Access (Developer Mode)

- SSH port: 9922, user: `prisoner`
- Key: decrypt `/var/luna/preferences/webos_rsa` with passphrase from Developer Mode app
- `luna-send` needs root (permission denied), `luna-send-pub` has limited access
- Useful for reading `/var/luna/preferences/*` settings files

---

## Key Files on TV Box

| Path | Purpose |
|------|---------|
| `/data/local/ssh/ssh` | OpenSSH client binary |
| `/data/local/ssh/ssh-keygen` | Key generation tool |
| `/data/local/ssh/id_tunnel` | Private key for tunnel |
| `/data/local/ssh/id_tunnel.pub` | Public key (on Oracle VM authorized_keys) |
| `/data/local/ssh/known_hosts` | Oracle VM host key |
| `/data/local/ssh/tunnel.sh` | Tunnel script (reconnecting loop) |
| `/data/local/ssh/tunnel.log` | Tunnel log file |
| `/data/local/ssh/termux-run.sh` | Helper to run Termux commands via ADB |
| `/system/etc/init/ssh_tunnel.rc` | Init service (triggers on boot) |

## Key Files on Oracle VM

| Path | Purpose |
|------|---------|
| `/home/tunnel/.ssh/authorized_keys` | TV box tunnel key (restricted) |
| `~/agent-repos/scrcpy-mcp/` | scrcpy-mcp server (to be cloned) |

---

## Display Fix (Dead Left ~25% of TV Panel)

The TV's left ~25% (480px) is dead/black. Video playback is handled by **mpv-android** with right-alignment to avoid the dead zone.

### mpv-android Configuration

Package: `is.xyz.mpv` — config persists at `/data/data/is.xyz.mpv/files/mpv.conf`

```ini
hwdec=no
video-zoom=-0.415
video-align-x=1
keepaspect=yes
```

- `video-zoom=-0.415` — shrinks video to 75% (log2(0.75) = -0.415), fitting the visible area
- `video-align-x=1` — pushes video flush to the right edge
- `hwdec=no` — required for video-align-x/video-zoom to work (software decoding)
- Result: 1440x810 video right-aligned, black padding over the dead zone, no content lost

To adjust for different dead zone sizes:
- 20% dead: `video-zoom=-0.322`
- 25% dead: `video-zoom=-0.415`
- 30% dead: `video-zoom=-0.515`

### Playing Videos Through mpv (AI Assistant Workflow)

**YouTube via mpv (right-aligned):**
```bash
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "https://www.youtube.com/watch?v=VIDEO_ID" \
  -n is.xyz.mpv/.MPVActivity
```

**Stremio content via mpv:** Configure Stremio to use mpv as external player (Settings > Player), or launch mpv directly with a stream URL.

**Direct URL in mpv:**
```bash
adb -s localhost:15555 shell am start -a android.intent.action.VIEW \
  -d "URL_HERE" \
  -n is.xyz.mpv/.MPVActivity
```

### Audio Language Preference (Latin American Spanish)

mpv is configured to prefer Latin American Spanish audio, then Spain Spanish, then English:

```ini
alang=es-419,es-MX,es-LA,lat,latino,la,spa-lat,spa-la,spa-mx,es-mx,es-la,es,spa,spanish,eng,en
slang=es-419,es-MX,es-LA,lat,latino,spa,es,eng,en
```

### Finding Latino Streams (AI Assistant)

When searching for streams via addon APIs, filter for Latino content:

```bash
# Filter Torrentio results for Latino streams
curl -s "https://torrentio.strem.fun/stream/movie/IMDB_ID.json" | \
  python3 -c "
import sys,json,re
d = json.load(sys.stdin)
pat = re.compile(r'latino|lat[^a-z]|es.la|es.mx|latin', re.IGNORECASE)
for s in d.get('streams',[]):
    title = s.get('title','')
    if pat.search(title):
        ih = s.get('infoHash','')
        fi = s.get('fileIdx',0)
        url = f'http://127.0.0.1:11470/{ih}/{fi}' if ih else s.get('url','')
        print(f'{title[:80]}')
        print(f'URL: {url}')
"
```

### Recommended Stremio Addons for Latino Content

| Addon | Purpose | Config |
|-------|---------|--------|
| Torrentio | Torrents with Cinecalidad provider | `torrentio.strem.fun/configure` — enable Cinecalidad, set Priority Language = Latino |
| Cuevana/HomeCine | Direct HTTP streams in LATAM Spanish | Search on `stremio-addons.net`, configure with "Latin American Spanish" |
| AIOStreams | Aggregator with regex filtering | `aiostreams.elfhosted.com/stremio/configure` — set language filter to Latino |
| Peerflix | Spanish-focused streams | `config.peerflix.mov` |
| MediaFusion | Alternative torrent indexer | Additional coverage alongside Torrentio |

> **Note:** SmartTube and Stremio's built-in players render centered (no offset). For content to appear on the visible area of the TV, always route playback through mpv.

---

## Tips for Navigating the TV Box Remotely

### Use UI snapshots instead of screenshots

Screenshots consume large amounts of context/tokens. Use `uiautomator dump` to get a text-based view of the screen:

```bash
# Get all visible text elements and their positions
adb -s localhost:15555 shell "uiautomator dump /sdcard/ui.xml && cat /sdcard/ui.xml" | \
  tr '>' '>\n' | grep -oE '(text|content-desc|bounds)="[^"]*"' | \
  grep -v '=""' | head -30
```

**WARNING**: `uiautomator dump` can dismiss popups/dialogs. If you're interacting with a dialog, take a screenshot first, then use snapshots for subsequent navigation.

Only use screenshots when:
- You need to see the visual layout (images, icons, video content)
- You need exact coordinates for tapping on non-text elements
- UI dump returns nothing useful (some apps use custom rendering)

### Navigation via key events (preferred for Android TV)

Android TV is designed for remote control navigation. Use d-pad keys instead of tap coordinates when possible:

```bash
# D-pad navigation (most reliable on Android TV)
adb shell input keyevent KEYCODE_DPAD_UP
adb shell input keyevent KEYCODE_DPAD_DOWN
adb shell input keyevent KEYCODE_DPAD_LEFT
adb shell input keyevent KEYCODE_DPAD_RIGHT
adb shell input keyevent KEYCODE_DPAD_CENTER    # Select/confirm (like pressing OK)
adb shell input keyevent KEYCODE_ENTER          # Also works as select

# System keys
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_BACK
adb shell input keyevent KEYCODE_MENU

# Media keys
adb shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE
adb shell input keyevent KEYCODE_MEDIA_NEXT
adb shell input keyevent KEYCODE_MEDIA_PREVIOUS
adb shell input keyevent KEYCODE_MEDIA_STOP
adb shell input keyevent KEYCODE_VOLUME_UP
adb shell input keyevent KEYCODE_VOLUME_DOWN
adb shell input keyevent KEYCODE_MUTE
```

### Tapping by text (find element, then tap center of bounds)

When you need to tap a specific UI element:

```bash
# 1. Dump UI and find the element
adb shell "uiautomator dump /sdcard/ui.xml && cat /sdcard/ui.xml" | \
  tr '>' '>\n' | grep "Settings" | grep -oE 'bounds="\[[0-9,]+\]\[[0-9,]+\]"'
# Output: bounds="[100,200][300,400]"

# 2. Calculate center: x=(100+300)/2=200, y=(200+400)/2=300
adb shell input tap 200 300
```

### Typing text

```bash
# Type text (spaces are encoded as %s)
adb shell input text "hello%sworld"

# For special characters, use key events:
adb shell input keyevent KEYCODE_AT          # @
adb shell input keyevent KEYCODE_PERIOD      # .
adb shell input keyevent KEYCODE_SLASH       # /
```

### App launching patterns

```bash
# Open a URL in the browser
adb shell am start -a android.intent.action.VIEW -d "https://youtube.com"

# Launch app by package name
adb shell monkey -p com.liskovsoft.smarttubetv.beta -c android.intent.category.LEANBACK_LAUNCHER 1

# Force stop an app
adb shell am force-stop com.google.android.youtube.tv

# Go to Android TV home screen
adb shell input keyevent KEYCODE_HOME
```

### Workflow: screenshot → analyze → act

When navigating an unfamiliar screen:

1. **First**, try a UI snapshot to understand the layout
2. If the snapshot is insufficient (custom UI, images), take a screenshot
3. Use d-pad navigation when possible (more reliable than taps on TV)
4. After taking an action, snapshot again to verify the result

```bash
# Example: navigate to YouTube and search
adb shell input keyevent KEYCODE_HOME                    # Go home
adb shell monkey -p com.liskovsoft.smarttubetv.beta 1    # Open SmartTube
sleep 3
adb shell input keyevent KEYCODE_DPAD_UP                 # Navigate to search
adb shell input keyevent KEYCODE_DPAD_CENTER              # Open search
sleep 1
adb shell input text "relaxing%smusic"                   # Type search query
adb shell input keyevent KEYCODE_ENTER                    # Search
```

### scrcpy (Mirror TV box to PC)

```bash
# Mirror screen to PC, keep audio on TV
scrcpy --serial 192.168.100.16:5555 --no-audio

# Mirror with audio on both PC and TV
scrcpy --serial 192.168.100.16:5555 --audio-dup
```

### Monitoring what's on screen

```bash
# Quick check: what app is in foreground?
adb shell dumpsys activity activities | grep mResumedActivity

# What's playing? (media session info)
adb shell dumpsys media_session | grep -A5 "metadata"
```
