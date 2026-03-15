# Remote Control Setup (Claude Code ↔ Termux)

How to let a remote Claude Code Linux instance SSH into your rooted Android phone and control it — without needing Tailscale running permanently.

---

## Prerequisites

- Rooted Android phone with Termux
- A remote Linux server (e.g., Oracle Cloud) with a public IP and SSH on port 22
- Both devices initially on the same network (Tailscale, LAN, etc.) for the one-time setup

---

## 1. Initial SSH Setup (One-Time)

### On the Linux server

Generate an SSH key if you don't have one:
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
```

### On Termux

Install and start SSH server:
```bash
pkg install openssh -y
sshd
# SSH server runs on port 8022
```

Add the server's public key so it can connect to your phone:
```bash
mkdir -p ~/.ssh
echo "PASTE_SERVER_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
```

### On Termux — Generate your own key

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# Copy this output
```

### On the Linux server — Authorize your phone

```bash
echo "PASTE_PHONE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
```

---

## 2. SSH Config (Termux → Server)

Add to `~/.ssh/config` on Termux:

```
Host claw
    HostName SERVER_PUBLIC_IP
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519

Host claw-tunnel
    HostName SERVER_PUBLIC_IP
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    RemoteForward 2222 localhost:8022
    LocalForward 5900 localhost:5900
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ExitOnForwardFailure yes
```

### What each alias does

| Alias | Purpose |
|---|---|
| `ssh claw` | Simple SSH to the server |
| `ssh claw-tunnel` | SSH + reverse tunnel (server can SSH back to phone on port 2222) + VNC forward (view server display on phone via `localhost:5900`) |

---

## 3. SSH Config (Server → Phone)

Add to `~/.ssh/config` on the Linux server:

```
Host termux
    HostName localhost
    Port 2222
    User u0_a598
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
```

> **Note:** Replace `u0_a598` with your Termux user (run `whoami` in Termux to check).

---

## 4. Usage

### From Termux — connect and open tunnel:
```bash
ssh claw-tunnel
```

### From the Linux server — SSH back to the phone (while tunnel is active):
```bash
ssh termux
```

### VNC — view the server's display from your phone:

While `ssh claw-tunnel` is running, open **aVNC** on your phone:
- **Host:** `localhost`
- **Port:** `5900`
- Traffic is encrypted through the SSH tunnel

---

## 5. Phone Control Tools

### Installed packages

```bash
pkg install termux-api android-tools openssh
```

You also need the **Termux:API** companion app installed (from F-Droid or GitHub releases — the Play Store version does not work).

### ADB (local, with root)

Enable ADB over TCP so commands can be run from Termux:

```bash
su -c 'setprop service.adb.tcp.port 5555 && stop adbd && start adbd'
adb connect localhost:5555
```

### Available capabilities

#### Via ADB (root)

| Capability | Command |
|---|---|
| Screenshot | `adb shell screencap -p /sdcard/screen.png` |
| Tap screen | `adb shell input tap X Y` |
| Type text | `adb shell input text "hello"` |
| Swipe | `adb shell input swipe X1 Y1 X2 Y2 [duration_ms]` |
| Long press | `adb shell input swipe X Y X Y 1000` |
| Press key | `adb shell input keyevent KEYCODE_BACK` |
| Open app | `adb shell am start -n com.package/.Activity` |
| Force stop app | `adb shell am force-stop com.package` |
| List packages | `adb shell pm list packages` |
| Screen on/off | `adb shell input keyevent KEYCODE_WAKEUP` / `KEYCODE_SLEEP` |
| Screen size | `adb shell wm size` |
| Dump UI tree | `adb shell uiautomator dump && adb shell cat /sdcard/window_dump.xml` |
| Notifications | `adb shell dumpsys notification` |
| Volume | `adb shell media volume --set N` |
| Install APK | `adb install /path/to/app.apk` |
| File system | Full root access via `su` |
| Clipboard get | `adb shell su -c "service call clipboard 2 i32 1 i32 0"` |

Common key events: `KEYCODE_HOME`, `KEYCODE_BACK`, `KEYCODE_ENTER`, `KEYCODE_MENU`, `KEYCODE_VOLUME_UP`, `KEYCODE_VOLUME_DOWN`, `KEYCODE_POWER`, `KEYCODE_TAB`, `KEYCODE_DEL`.

#### Via Termux:API

| Capability | Command |
|---|---|
| Battery status | `termux-battery-status` |
| Vibrate | `termux-vibrate -d 500` |
| Notifications | `termux-notification --title "Hi" --content "Hello"` |
| Toast | `termux-toast "message"` |
| Clipboard get | `termux-clipboard-get` |
| Clipboard set | `termux-clipboard-set "text"` |
| Camera photo | `termux-camera-photo -c 0 /path/to/photo.jpg` |
| Location | `termux-location` |
| TTS (speak) | `termux-tts-speak "hello"` |
| Brightness | `termux-brightness 255` |
| Torch | `termux-torch on` / `termux-torch off` |
| Fingerprint | `termux-fingerprint` |
| Contacts | `termux-contact-list` |
| Call log | `termux-call-log` |
| SMS list | `termux-sms-list` |
| Send SMS | `termux-sms-send -n NUMBER "message"` |
| Sensors | `termux-sensor -s accelerometer -n 1` |
| WiFi info | `termux-wifi-connectioninfo` |
| WiFi scan | `termux-wifi-scaninfo` |
| Open URL | `termux-open-url "https://example.com"` |
| Share file | `termux-share /path/to/file` |
| Media scan | `termux-media-scan /path/to/file` |

> **Note:** Termux:API requires the companion app from F-Droid. The Google Play version is not functional.

---

## 6. Putting It All Together

With the tunnel active, a Claude Code instance on the server can:

1. **SSH to the phone**: `ssh termux "command"`
2. **Take screenshots**: `ssh termux "adb shell screencap -p /sdcard/s.png" && scp -P 2222 localhost:/sdcard/s.png /tmp/`
3. **Tap/swipe/type**: `ssh termux "adb shell input tap 500 1000"`
4. **Open apps**: `ssh termux "adb shell am start -n com.whatsapp/.Main"`
5. **Read notifications**: `ssh termux "adb shell dumpsys notification --noredact"`
6. **Dump UI hierarchy**: `ssh termux "adb shell uiautomator dump && adb shell cat /sdcard/window_dump.xml"`
7. **Send files to/from phone**: `scp -P 2222 localfile localhost:/sdcard/`

### Example: screenshot → analyze → tap

```bash
# Take screenshot
ssh termux "adb shell screencap -p /sdcard/screen.png"
# Copy to server
scp -P 2222 localhost:/sdcard/screen.png /tmp/phone.png
# Analyze the image (Claude can read it)
# Then tap at coordinates
ssh termux "adb shell input tap 350 800"
```

---

## 7. Keep the Tunnel Alive

To prevent the tunnel from dying when the phone sleeps:

```bash
# In Termux, before connecting:
termux-wake-lock

# Then connect:
ssh claw-tunnel
```

To auto-reconnect if the connection drops, use `autossh` (install with `pkg install autossh`):

```bash
autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" claw-tunnel
```
