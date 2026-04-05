# TV Box Knowledge Base — Lessons Learned

Everything discovered while setting up remote control of the X88 Pro 13 Android TV Box connected to an LG 75UN8000PSB TV.

---

## Device Details

- **TV Box**: X88 Pro 13 (RK3528 quad-core A53, Android TV 13, 4GB RAM, 32GB ROM)
- **Root**: Stock pre-rooted firmware (`su 0` works), SELinux Permissive
- **Magisk**: Installed but daemon doesn't run (stock root, not Magisk root). `service.d` scripts don't execute.
- **System partition**: Writable after `su 0 mount -o remount,rw /system`
- **TV**: LG 75UN8000PSB (WebOS, 75", left ~25% / 480px of panel is dead)
- **TV Box HDMI port**: HDMI_4 on the LG TV

---

## ADB Over TCP — The Ongoing Battle

### The Problem
Android's wireless debugging feature overrides `persist.adb.tcp.port` with a random port (30000-50000) every time it's toggled. This persisted value takes priority on next boot, breaking our fixed port 5555.

### What We Tried
| Approach | Result |
|----------|--------|
| `persist.adb.tcp.port=5555` via setprop | Overwritten by wireless debugging toggle |
| `service.adb.tcp.port=5555` in build.prop | Read at boot but overridden by persist value |
| `adb_tcp.rc` init script on `sys.boot_completed=1` | Works for current session but persist property wrong on next boot |
| Settings database `adb_enabled=1`, `adb_wifi_enabled=1` | Helps but not sufficient alone |
| `persist.internet_adb_enable=0` | **BROKE ALL NETWORK ADB** — don't disable this |
| `persist.adb.tls_server.enable=0` | **KILLED WIRELESS DEBUGGING** — don't disable this |

### Current Solution (Partial)
- `/system/build.prop` has `service.adb.tcp.port=5555`
- `/system/etc/init/adb_tcp.rc` sets port and restarts adbd on boot
- Settings database has `adb_enabled=1`
- **Still fails sometimes** — wireless debugging override persists across reboots

### Root Cause Found
The Rockchip firmware (`/vendor/etc/init/hw/init.rk30board.rc`) has a built-in mechanism:
```
on property:persist.internet_adb_enable=1
    setprop service.adb.tcp.port 5555
    restart adbd
```
This WORKS — but Android's wireless debugging system (`persist.adb.tls_server.enable=1`) overrides it with a random port. Fix: disable wireless debugging TLS (`persist.adb.tls_server.enable=0`) and rely on Rockchip's `internet_adb` mechanism.

### Deployed Safety Net
- `/data/local/tmp/adb_watchdog.sh` — checks every 60s, corrects port if overridden
- `/system/etc/init/adb_watchdog.rc` — starts watchdog on boot
- `/system/etc/init/adb_tcp.rc` — delayed (15s) port override on boot

### What NOT to Do
- **Don't set `persist.internet_adb_enable=0`** — kills all network ADB (Rockchip init sets port to 0)
- **Don't set `persist.adb.tls_server.enable=0` via ADB** — kills current wireless debugging session (use it only when you have another way to connect)
- **Don't `setprop ctl.restart adbd` while scrcpy is running** — kills the connection
- **Don't reboot without warning the user** — they may lose scrcpy session
- **Don't `setprop persist.*` right before rebooting** — may crash adbd during shutdown

### If ADB Stops Working After Reboot
1. Go to Settings → Developer Options on the TV box
2. Enable wireless debugging
3. Note the IP:port shown
4. Connect: `adb connect IP:PORT`
5. Then force port 5555: `adb shell su 0 setprop service.adb.tcp.port 5555 && su 0 setprop persist.adb.tcp.port 5555 && su 0 setprop ctl.restart adbd`
6. Reconnect: `adb connect IP:5555`

---

## Tasker on Android TV — BROKEN

### What Doesn't Work
- **HTTP Request event** (port 1821): Socket binds but profile never triggers. Returns 503 on all requests. Same Tasker version (6.6.20) works perfectly on a phone.
- **`am broadcast ACTION_TASK`**: Silently fails. Android TV 13 broadcast restrictions drop broadcasts to background apps.
- **Tasker UI on Android TV**: No three-dot overflow menu. Preferences inaccessible without `am start -a net.dinglisch.android.tasker.ACTION_OPEN_PREFS`.
- **File-based IPC bridge**: Designed but never tested (abandoned in favor of scrcpy-mcp).

### Root Cause
Android TV 13 + Tasker = broken event processing. The NanoHTTPD socket listener survives but the higher-level Tasker infrastructure doesn't dispatch events to profiles. Also, "Allow External Access" (`aExt`) must be enabled in Tasker preferences, which is inaccessible via the normal TV UI.

### What Does Work
- Running Tasker tasks manually via the UI
- The `MCP generate_api_key` task works
- API key: `tk_HcUEv3-SQjy3yihV39nYUw` (stored in `%tasker_api_key`)

---

## Display Offset — Dead TV Panel (Left 25%)

### What Doesn't Work
| Approach | Result |
|----------|--------|
| `wm overscan` | Removed in Android 13 |
| `wm size 1344x1080` | Centers content, TV auto-scales to fill |
| `wm size 1440x810` | TV auto-scales, can't position |
| RRO display cutout overlay APK | Didn't persist after reboot, caused slow boot |
| `persist.sys.overscan` property | Set but Rockchip HWC ignores it |
| `service call window 74` (setOverscan) | No effect |
| `cmd window set-letterbox-style --horizontalPositionMultiplier 1.0` | Only affects letterboxed apps, not fullscreen video |
| `cmd window folded-area` | Only affects fold-aware apps |
| Black overlay APK (WindowManager TYPE_SYSTEM_ERROR) | Renders above UI but BELOW hardware-decoded video |
| `app_process` overlay | NullPointerException in AppOpsManager (no package identity) |
| LG TV "All Direction Zoom" + `wm size` | TV auto-scales everything |
| LG TV service menu | Can't access (no number buttons on remote, `webosapp.club/instart/` is down) |

### What WORKS: mpv `video-align-x`
```ini
# /data/data/is.xyz.mpv/files/mpv.conf
hwdec=no
video-zoom=-0.415
video-align-x=1
keepaspect=yes
alang=es-419,es-MX,es-LA,lat,latino,la,spa-lat,spa-la,spa-mx,es-mx,es-la,es,spa,spanish,eng,en
slang=es-419,es-MX,es-LA,lat,latino,spa,es,eng,en
```

- `video-zoom=-0.415` — shrinks to 75% (log2(0.75))
- `video-align-x=1` — pushes video flush right
- `hwdec=no` — **REQUIRED** for video-align-x to work (hardware decoding bypasses mpv's positioning)
- Trade-off: software decoding is slightly less smooth than hardware decoding
- For smooth playback without offset: use Stremio/SmartTube built-in players (centered)

### Key Discovery
- `video-align-x` and `video-zoom` ONLY work with `hwdec=no`
- With `hwdec=auto`/`hwdec=mediacodec`, video renders via SurfaceView bypassing mpv's GPU pipeline
- `vf=lavfi=[pad]` filters force CPU processing even with hwdec — too slow on RK3528
- Prefer **x264** over x265 streams (faster software decode)
- 720p x264 plays smoother than 1080p but has fewer torrent seeders

---

## LG TV Control (WebOS SSAP)

### Connection
- IP: `192.168.100.13`, WSS port 3001
- **Must register with full manifest** for elevated permissions (without it, everything returns 401)
- Client key persists across reboots

### Key Discoveries
- **Registration without manifest** → 401 on all commands
- **Registration with full manifest** (permissions array) → full control
- **Service menu** (`com.webos.app.factorywin`): launches successfully via SSAP but **nothing visible** on screen
- **Developer Mode**: 1000-hour timer (not power-off expiry). Reset periodically.
- **Wake-on-LAN**: Doesn't work despite `wolwowlOnOff=true` and Quick Start+ enabled
- **CEC wake**: `su 0 cmd hdmi_control onetouchplay` — **WORKS** (reports "timed out" but TV turns on)
- **CEC requires**: SIMPLINK (HDMI-CEC) ON + Auto Power Sync ON on the LG TV
- **TV SSH**: `prisoner@192.168.100.13:9922`, key from `/var/luna/preferences/webos_rsa` (encrypted, decrypt with Dev Mode passphrase)
- **`luna-send-pub`**: Runs but returns empty for most queries as prisoner user
- **PalmServiceBridge**: Not available in the WebOS browser

### CEC Auto-Switch Fix
The TV box auto-switches the TV input to HDMI_4 on every boot via CEC "Active Source" message. Fixed by:
```bash
su 0 cmd hdmi_control cec_setting set power_control_mode none
```
This persists across reboots. Intentional `onetouchplay` still works — the AI assistant can still wake the TV and switch input on demand.

### What NOT to Do
- Don't turn TV off if you need immediate CEC wake — put to standby via SSAP, CEC wakes from standby only

---

## Media Playback Architecture

### YouTube → SmartTube
- Package: `org.smarttube.stable` (v31.30)
- Stable version works. Beta (`com.liskovsoft.smarttubetv.beta`) shows "Cannot load content"
- Search: `am start -d "https://youtube.com/results?search_query=QUERY" -n org.smarttube.stable/com.liskovsoft.smartyoutubetv2.tv.ui.main.SplashActivity`
- Play: same with `watch?v=VIDEO_ID`
- Extract results via `uiautomator dump`

### Movies/Shows → Stremio + mpv
- Stremio package: `com.stremio.one` (v1.9.12)
- **Stremio must be running** for streaming server on port 11470
- Search: Cinemeta API `https://v3-cinemeta.strem.io/catalog/movie/top/search=QUERY.json`
- Streams: Torrentio API `https://torrentio.strem.fun/stream/movie/IMDB_ID.json`
- **Torrentio blocked from Oracle VM** (Cloudflare 403) — query via TV box SSH instead
- Play in mpv: `am start -d "http://127.0.0.1:11470/{hash}/{idx}" -n is.xyz.mpv/.MPVActivity`
- Deep link format: `stremio:///detail/series/{id}/{id}:{season}:{episode}`

### Stream Selection Priorities
1. **Language**: Latino/DUAL/Multi > English
2. **Resolution**: 1080p preferred (720p acceptable)
3. **Codec**: x264 > x265/HEVC (faster software decode)
4. **Seeders**: More = faster loading
5. **Avoid 4K**: Too heavy for software decode on RK3528
6. Note: `MultiSubs` = subtitles only (usually English audio). `DUAL` = two audio tracks.

### IPTV
- Free M3U playlists exist (iptv-org/iptv) but streams are unreliable
- Not worth setting up — most channels are broken or geo-blocked

---

## Reverse SSH Tunnel (TV Box → Oracle VM)

### Setup
- TV box SSH key: `/data/local/ssh/id_tunnel` (ed25519)
- Oracle VM tunnel user: `tunnel` (no shell, port-forwarding only)
- Tunnel script: `/data/local/ssh/tunnel.sh` (reconnecting loop)
- Init service: `/system/etc/init/ssh_tunnel.rc` (triggers on `sys.boot_completed=1`)
- Tunnel forwards: ADB (15555→5555), Termux SSH (18022→8022)

### Key Points
- Tunnel auto-establishes on boot
- Uses `ssh -R` for reverse port forwarding
- `ServerAliveInterval=30`, `ExitOnForwardFailure=yes`
- TV box IP may change (DHCP) — doesn't matter since TV box initiates outbound connection
- Termux SSH (port 18022) is flaky — `run-as com.termux` sshd doesn't start reliably

---

## Termux API

### Wake-up Required
Android kills Termux:API in background. Must wake it first:
```bash
adb shell "am broadcast -a com.termux.api.ACTION_WAKE_UP -n com.termux.api/.TermuxApiReceiver"
```
This is silent — no UI, no app switching.

### What Works
- `termux-battery-status` ✅
- `termux-wifi-connectioninfo` ✅
- `termux-tts-speak` ✅ (needs speaker)
- `termux-clipboard-set/get` ✅ (after wake-up)

### What Doesn't Work
- `termux-toast` ❌ (Android TV doesn't show toasts from background apps)

---

## Debloated Apps
21 bloatware packages removed via `pm uninstall -k --user 0` (reversible):
- Chinese app stores (overseas.store, chihihgs.store, aptoidetv, aptoide)
- Bloatware (scooper, tiktok, mgandroid, mgstv, rocketfly)
- Unused (camera2, printspooler, bookmarkprovider, pinyin input, changeled, stresstest, devicetest, wifitest)
- Streaming (Netflix, Disney+ — user doesn't use these on the TV box)
- AirScreen, Live TV apps

---

## Files on TV Box

| Path | Purpose |
|------|---------|
| `/system/build.prop` | ADB TCP port 5555 + persistent properties |
| `/system/etc/init/ssh_tunnel.rc` | Boot service — SSH tunnel |
| `/system/etc/init/adb_tcp.rc` | Boot service — ADB TCP restart |
| `/data/local/ssh/ssh` | OpenSSH client binary |
| `/data/local/ssh/id_tunnel` | SSH key for tunnel |
| `/data/local/ssh/tunnel.sh` | Tunnel script (reconnecting loop) |
| `/data/local/ssh/tunnel.log` | Tunnel log |
| `/data/local/ssh/termux-run.sh` | Helper to run Termux commands via ADB |
| `/data/data/is.xyz.mpv/files/mpv.conf` | mpv config (right-aligned + language prefs) |
| `/sdcard/fix_adb.sh` | Script to re-apply ADB TCP fix |
| `/data/misc/adb/adb_keys` | Pre-authorized ADB keys |

---

## scrcpy Tips

- **Keep audio on TV**: `scrcpy --serial IP:PORT --no-audio`
- **Audio on both**: `scrcpy --serial IP:PORT --audio-dup`
- **Remote via Oracle VM**: `ssh -L 5556:localhost:15555 claudeclaw` then `scrcpy --serial localhost:5556 --no-audio --max-fps 15 --video-bit-rate 1M --max-size 720`
- **scrcpy can't capture hardware video**: Shows black where SurfaceView renders. Video plays fine on TV.
- **Don't restart adbd while scrcpy is running** — kills the connection
