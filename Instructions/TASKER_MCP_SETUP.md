# Tasker MCP Setup (Claude Code → Tasker on Phone)

Control Tasker on your rooted Android phone from Claude Code on the Linux server via the [tasker-mcp](https://github.com/dceluis/tasker-mcp) MCP server.

---

## Prerequisites

- Working SSH tunnel from server to phone (see [REMOTE_CONTROL_SETUP.md](REMOTE_CONTROL_SETUP.md))
- Tasker **6.2+** installed on the phone (HTTP Request event requires 6.2+)
- ADB connected locally on the phone (`adb connect localhost:5555`)

---

## 1. Import the Tasker Project (Phone)

Push the project XML to the phone:
```bash
# From the Linux server
ssh termux "adb push /path/to/mcp_server.prj.xml /sdcard/Download/"
```

In Tasker on the phone:
1. Long-press the **Home** icon (bottom tab bar)
2. Tap **Import Project**
3. Browse to `Download/mcp_server.prj.xml` and import it

You should see a new **mcp-server** project tab at the bottom with:
- **Profile**: "MCP Request Received" (HTTP Request on port 1821, POST /run_task)
- **Task**: "MCP perform_task"
- Multiple tool tasks (flashlight, flash text, battery, etc.)

---

## 2. Generate an API Key (Phone)

In Tasker:
1. Go to the **Tasks** tab
2. Find **"MCP generate_api_key"**
3. Tap the play button to run it
4. The key (format `tk_...`) is generated and stored in the project variable `%tasker_api_key`
5. Copy it — you'll need it for the server config

---

## 3. Verify the HTTP Server is Running (Phone)

Tasker's HTTP server starts **automatically** when the "MCP Request Received" profile is enabled — there is no separate toggle. The profile uses Tasker's HTTP Request event which creates a server on port 1821.

Verify from Termux:
```bash
# Check Tasker is listening (will show tcp6 [::]:1821)
adb shell netstat -tlnp | grep 1821
```

> **Important**: Tasker listens on **IPv6 only** (`[::]:1821`), not IPv4. This affects how the SSH tunnel must be configured.

### Troubleshooting: Nothing listening on 1821

1. Check the profile is **enabled** (green toggle) in the Profiles tab
2. Make sure you're on the **mcp-server** project tab
3. Force-stop Tasker and reopen it
4. Run `keep-alive start` in Termux to prevent Xiaomi from killing Tasker
5. Verify Tasker version: `adb shell dumpsys package net.dinglisch.android.taskerm | grep versionName` (must be 6.2+)

---

## 4. SSH Tunnel for Port 1821 (Linux Server)

The SSH tunnel must forward to `localhost:1821` on the phone, which resolves to IPv6 `[::1]` — matching where Tasker listens.

```bash
ssh -f -N -L 1821:localhost:1821 termux
```

Verify the tunnel:
```bash
ss -tlnp | grep 1821
# Should show LISTEN on 127.0.0.1:1821 and [::1]:1821
```

> **Do NOT add `LocalForward` to `~/.ssh/config`** for the termux host — it conflicts when multiple SSH sessions are opened (the second connection fails with "Address already in use"). Run the tunnel manually or via a startup script instead.

### Auto-start the tunnel

Add to a startup script or cron:
```bash
# Only create tunnel if not already running
ss -tlnp | grep -q ':1821 ' || ssh -f -N -L 1821:localhost:1821 termux
```

---

## 5. Install the MCP Binary (Linux Server)

The tasker-mcp repo includes pre-built binaries:
```bash
cd /home/ubuntu/agent-repos/tasker-mcp/dist/

# Use the aarch64 binary for ARM64 servers (e.g., Oracle Cloud Ampere)
chmod +x tasker-mcp-server-cli-aarch64

# Use x86_64 for Intel/AMD servers
chmod +x tasker-mcp-server-cli-x86_64
```

Check your architecture with `uname -m`.

### Quick test
```bash
# Should respond with tool list JSON
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  ./tasker-mcp-server-cli-aarch64 \
    -tools toolDescriptions.json \
    -tasker-host 127.0.0.1 \
    -tasker-port 1821 \
    -tasker-api-key "tk_YOUR_KEY" \
    -mode stdio
```

---

## 6. Configure in Claude Code (Linux Server)

Add to the **project-level** `mcpServers` in `~/.claude.json` (not global — so only authorized users can control the phone):

```json
{
  "projects": {
    "/home/ubuntu": {
      "mcpServers": {
        "tasker-franz": {
          "command": "/home/ubuntu/agent-repos/tasker-mcp/dist/tasker-mcp-server-cli-aarch64",
          "args": [
            "-tools", "/home/ubuntu/agent-repos/tasker-mcp/dist/toolDescriptions.json",
            "-tasker-host", "127.0.0.1",
            "-tasker-port", "1821",
            "-tasker-api-key", "tk_YOUR_KEY",
            "-mode", "stdio"
          ],
          "env": {}
        }
      }
    }
  }
}
```

Restart Claude Code for the MCP to load.

---

## 7. Test It

In Claude Code:
```
Turn on my flashlight
```

Claude calls `tasker_toggle_flashlight` → MCP binary POSTs to `127.0.0.1:1821` → SSH tunnel → Tasker on phone → flashlight turns on.

---

## Available Tools

| Tool | Description |
|------|-------------|
| `tasker_toggle_flashlight` | Turn flashlight on/off |
| `tasker_flash_text` | Show a toast message on the phone |
| `tasker_get_battery_level` | Get battery percentage |
| `tasker_say` | Text-to-speech on the phone |
| `tasker_set_volume` | Set media/ring/notification volume |
| `tasker_get_volume` | Get current volume levels |
| `tasker_toggle_wifi` | Toggle WiFi on/off |
| `tasker_browse_url` | Open a URL in the phone's browser |
| `tasker_send_sms` | Send an SMS |
| `tasker_call_number` | Initiate a phone call |
| `tasker_set_alarm` | Set an alarm |
| `tasker_take_photo` | Take a photo with the camera |
| `tasker_screenshot` | Take a screenshot |
| `tasker_get_location` | Get GPS coordinates |
| `tasker_get_clipboard` | Read clipboard contents |
| `tasker_set_clipboard` | Set clipboard contents |
| `tasker_play_music` | Play a music file |
| `tasker_get_contacts` | List contacts |
| `tasker_create_task` | Create a Google Task |
| `tasker_list_files` | List files in a directory |
| `tasker_lamp_on` / `tasker_lamp_off` | Smart home lamp control |
| `tasker_print` | Print to a connected printer |

---

## Adding Custom Tools

Every Tasker task can become an AI tool:

1. Create a new task in Tasker (e.g., "MCP Toggle Bluetooth")
2. Add a **comment** in the task settings — this becomes the tool description Claude sees
3. For parameters, use **Task Variables** with:
   - **Configure on Import**: unchecked
   - **Immutable**: true
   - **Value**: empty (tells tasker-mcp it's an MCP argument)
   - **Prompt** field: becomes the parameter description
   - **Same as Value** checked: marks it as required
4. Re-export the project and regenerate `toolDescriptions.json` using the utility in `utils/`

---

## Architecture

```
Claude Code  →  MCP (stdio)  →  tasker-mcp binary (server)
                                      ↓ HTTP POST
                              SSH tunnel (port 1821)
                                      ↓
                              Tasker HTTP Server (phone, IPv6 [::]:1821)
                                      ↓
                              MCP perform_task → individual tool tasks
```

---

## Key Gotchas

1. **Tasker listens on IPv6 only** — the tunnel must forward to `localhost` (not `127.0.0.1`) so it resolves to `[::1]`
2. **Don't use `LocalForward` in SSH config** — causes "Address already in use" conflicts on subsequent SSH connections
3. **Xiaomi kills Tasker aggressively** — always run `keep-alive start` in Termux before relying on the MCP
4. **403 errors** — the API key in the MCP config doesn't match `%tasker_api_key` in Tasker. Re-run the generate_api_key task and update the config
5. **Connection refused** — the SSH tunnel died. Re-run `ssh -f -N -L 1821:localhost:1821 termux`
6. **Connection timeout (hangs)** — you're hitting a path/method that doesn't match the profile (e.g., GET / instead of POST /run_task). This is normal — Tasker only responds to matching routes
