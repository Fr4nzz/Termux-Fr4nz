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
./termux-scripts/setup_ssh.sh
# (optional) zsh + OMZ:
./termux-scripts/install_zsh.sh
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

You’ll be asked for the password you set with `passwd` during setup.

> If using ADB over USB instead of Wi-Fi:
>
> ```powershell
> adb forward tcp:8022 tcp:8022
> ssh -p 8022 <username>@127.0.0.1
> ```

---

## 2) “Host identification has changed!” after reinstall

If you wipe/reinstall Termux or regenerate host keys, Windows saved the old key. Remove it:

```powershell
ssh-keygen -R "[127.0.0.1]:8022"      # if you connect via ADB port-forward
ssh-keygen -R "[<phone_ip>]:8022"     # if you connect via Wi-Fi IP
```

Then connect again and accept the new fingerprint.

---

## 3) Troubleshooting quick list

* **Connection refused / timeout**: ensure `sshd` is running; run `sshd` again. Phone and PC must be on the same Wi-Fi (if not using ADB).
* **Wrong user**: use `whoami` in Termux for the exact username (often `u0_aXXX`).
* **Phone sleeps & kills sshd**: while testing, in Termux run:

  ```sh
  termux-wake-lock
  ```
