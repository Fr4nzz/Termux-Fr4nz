# Connect from Windows to Termux (SSH)

This guide covers:
- Password login
- Key-based login (no password)
- Auto-discover & connect script
- Deleting an old host key if you reinstalled Termux
- Troubleshooting

---

## 0) Prereqs on the phone (Termux)

Run in Termux on the phone:

```sh
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/main/termux-scripts/setup_ssh.sh | bash
# Set a password when prompted:
passwd
```

Find your Termux username and phone IP:

```sh
whoami
ifconfig wlan0 | sed -n 's/.*inet \(addr:\)\?\([0-9.]*\).*/\2/p' | head -n1
# Or, if you have termux-api installed:
# termux-wifi-connectioninfo | jq -r '.ip'
```

---

## 1) Password login (easy start)

From Windows PowerShell or CMD:

```powershell
ssh -p 8022 <username>@<phone_ip>
# example:
# ssh -p 8022 u0_a612@192.168.1.5
```

You'll be asked for the password you set with `passwd` during setup.

> If using ADB over USB instead of Wi-Fi:
>
> ```powershell
> adb forward tcp:8022 tcp:8022
> ssh -p 8022 <username>@127.0.0.1
> ```

---

## 2) Key-based login (no more passwords)

Generate an SSH key on Windows (skip if you already have one):

```powershell
ssh-keygen -t ed25519
# Press Enter through all prompts (default path, no passphrase)
```

Copy your public key to Termux (enter your password one last time):

```powershell
cat ~/.ssh/id_ed25519.pub | ssh -p 8022 <username>@<phone_ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Test it — this should connect with **no password prompt**:

```powershell
ssh -p 8022 <username>@<phone_ip>
```

---

## 3) Auto-discover & connect (recommended)

Your phone's IP can change across Wi-Fi sessions. Instead of looking it up every time and setting up keys manually, use the connect script that does everything for you.

One-liner (no need to clone the repo):

```powershell
irm https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/main/windows-scripts/connect-termux.ps1 | iex
```

Or from the repo root:

```powershell
.\windows-scripts\connect-termux.ps1 <username>
```

The script handles the full setup automatically:
1. Scans your local network for port 8022 (~0.5 s)
2. Generates an SSH key if you don't have one
3. Copies the key to Termux if not already set up (asks password **once**)
4. Connects passwordless

On first run you'll enter your Termux password one time. Every run after that is fully automatic — no IP, no password.

If multiple devices have port 8022 open, it will list them and let you pick.

> **Note:** If PowerShell blocks the script, allow it with:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

---

## 4) "Host identification has changed!" after reinstall

If you wipe/reinstall Termux or regenerate host keys, Windows saved the old key. Remove it:

```powershell
ssh-keygen -R "[127.0.0.1]:8022"      # if you connect via ADB port-forward
ssh-keygen -R "[<phone_ip>]:8022"     # if you connect via Wi-Fi IP
```

Then connect again and accept the new fingerprint.

---

## 5) Troubleshooting quick list

* **Connection refused / timeout**: ensure `sshd` is running; run `sshd` again. Phone and PC must be on the same Wi-Fi (if not using ADB).
* **Wrong user**: use `whoami` in Termux for the exact username (often `u0_aXXX`).
* **Phone sleeps & kills sshd**: while testing, in Termux run:

  ```sh
  termux-wake-lock
  ```
* **Discovery script finds nothing**: make sure `sshd` is running on the phone and both devices are on the same Wi-Fi network.
