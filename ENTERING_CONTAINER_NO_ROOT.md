# Entering the container (no-root path with `proot`)

On Android, `rurima r` (ruri) needs kernel capabilities that only root has.  
For **no-root**, use `proot` (userspace emulation of namespaces/mounts).

## Ownership tip (only if you used sudo before)

If you previously pulled a container with `sudo`, fix ownership once:

```bash
ls -ld "$HOME/containers"
sudo chown -R "$USER:$USER" "$HOME/containers"
```

## (Optional) First-run fixups via proot

```bash
curl -fsSL https://raw.githubusercontent.com/RuriOSS/daijin/refs/heads/main/src/share/fixup.sh \
  | proot -0 -r "$HOME/containers/ubuntu-noble" /bin/sh
```

## Enter the container with proot

This binds `/proc`, `/sys`, `/dev`, and maps `/sdcard` to `~/sdcard`:

```bash
proot -0 \
  -r "$HOME/containers/ubuntu-noble" \
  -b /proc:/proc -b /sys:/sys -b /dev:/dev \
  -b /sdcard:/root/sdcard \
  -w /root /usr/bin/env -i \
  HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l
```

### Optional helper: `ubuntu` (proot)

```bash
P=/data/data/com.termux/files/usr
cat >"$P/bin/ubuntu" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="/data/data/com.termux/files/home/containers/ubuntu-noble"
SRC='/sdcard'  # requires `termux-setup-storage`
exec proot -0 -r "$C" \
  -b /proc:/proc -b /sys:/sys -b /dev:/dev \
  -b "$SRC":/root/sdcard -w /root /usr/bin/env -i \
  HOME=/root TERM=xterm-256color \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -l "$@"
SH
chmod 0755 "$P/bin/ubuntu"
hash -r
```

Usage:

```bash
ubuntu               # default shell (proot)
ubuntu /bin/bash -l  # run specific command
```

### Unmount/cleanup in proot

There is no unmount step. Just **exit** the shell; that ends the `proot` process and all children.
If you backgrounded something and want to nuke the session:

```bash
# Kill the current proot session (from another Termux shell):
pkill -f 'proot -0 -r .*containers/ubuntu-noble'
# or more selectively:
pgrep -fa 'proot -0 -r'   # inspect
kill -TERM <pid>          # then SIGKILL if needed
```

### Notes

* Proot is slower than native root; features like KVM, real cgroups/seccomp, and kernel mounts aren’t available.
* To access phone storage, run `termux-setup-storage` once in Termux; the bind `-b /sdcard:/root/sdcard` exposes it inside Ubuntu.
