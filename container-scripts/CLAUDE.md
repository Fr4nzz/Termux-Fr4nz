# Environment: Android/aarch64, Ubuntu chroot in Termux

- ~/sdcard — phone storage (photos, downloads, etc.)
- To run Termux commands: `ssh -p 8022 $(cat /etc/termux-user)@127.0.0.1 '<command>'` (keys pre-configured)
- Prefer Termux packages (`pkg install`) over apt when possible (lighter)
- Mobile device — keep solutions lightweight
