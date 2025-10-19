# Connect from Windows to Termux (SSH)

This guide covers:
- Password login
- Key-based login (recommended)
- Deleting an old host key if you reinstalled Termux
- Optional USB (ADB) method

---

## 0) Prereqs on the phone (Termux)

On the phone, after cloning this repo:

```sh
./setup_termux.sh
# This installs OpenSSH + zsh, prompts you to set a password, starts sshd, and makes zsh default.
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
# ssh -p 8022 u0_a612@192.168.100.109
```

You’ll be asked for the password you set with `passwd` during setup.

> If using ADB over USB instead of Wi-Fi:
>
> ```powershell
> adb forward tcp:8022 tcp:8022
> ssh -p 8022 <username>@127.0.0.1
> ```

---

## 2) Key-based login (recommended)

### 2.1 Generate a key on Windows

```powershell
ssh-keygen -t ed25519 -C "termux"
# Press Enter for defaults; a key pair is created in %USERPROFILE%\.ssh\
```

### 2.2 Install your public key on Termux

**Option A (one-liner, no extra tools on Windows):**

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh -p 8022 <username>@<phone_ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

**Option B (manual, if needed):**

1. Show your public key:

   ```powershell
   type $env:USERPROFILE\.ssh\id_ed25519.pub
   ```
2. Copy it, then on Termux:

   ```sh
   mkdir -p ~/.ssh
   nano ~/.ssh/authorized_keys   # paste the single line, save & exit
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

Now reconnect (no password prompt):

```powershell
ssh -p 8022 <username>@<phone_ip>
```

---

## 3) “Host identification has changed!” after reinstall

If you wipe/reinstall Termux or regenerate host keys, Windows saved the old key. Remove it:

```powershell
ssh-keygen -R "[127.0.0.1]:8022"      # if you connect via ADB port-forward
ssh-keygen -R "[<phone_ip>]:8022"     # if you connect via Wi-Fi IP
```

Then connect again and accept the new fingerprint.

(Optional) View fingerprints on Termux:

```sh
ssh-keygen -lf /data/data/com.termux/files/usr/etc/ssh/ssh_host_ed25519_key.pub
```

---

## 4) Troubleshooting quick list

* **Connection refused / timeout**: ensure `sshd` is running; run `sshd` again. Phone and PC must be on the same Wi-Fi (if not using ADB).
* **Wrong user**: use `whoami` in Termux for the exact username (often `u0_aXXX`).
* **Permission denied (publickey)**: fix perms on Termux:

  ```sh
  chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
  ```
* **Phone sleeps & kills sshd**: while testing, in Termux run:

  ```sh
  termux-wake-lock
  ```

