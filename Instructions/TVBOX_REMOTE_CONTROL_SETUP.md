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
| SmartTube (YouTube) | `com.liskovsoft.smarttubetv.beta` |
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
| `/system/etc/init/ssh_tunnel.rc` | Init service (triggers on boot) |

## Key Files on Oracle VM

| Path | Purpose |
|------|---------|
| `/home/tunnel/.ssh/authorized_keys` | TV box tunnel key (restricted) |
| `~/agent-repos/scrcpy-mcp/` | scrcpy-mcp server (to be cloned) |
