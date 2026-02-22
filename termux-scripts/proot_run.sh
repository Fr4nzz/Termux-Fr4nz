#!/data/data/com.termux/files/usr/bin/bash
# proot_run.sh — self-contained proot wrapper for running Linux containers on
# Android/Termux without root. Replaces the deprecated daijin proot_start.sh.
#
# Usage:
#   proot_run.sh -r <container_dir> [-e "extra proot args"] [command...]
#
# Installs to $PREFIX/bin/proot-run by the setup script.

set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"

PROC_DIR="$PREFIX/share/proot-proc"
CONTAINER_DIR=""
EXTRA_ARGS=""

# ── Generate minimal fake /proc files (once) ────────────────────────────────
setup_proc_files() {
  [ -d "$PROC_DIR" ] && return 0
  mkdir -p "$PROC_DIR"

  # Minimal set that prevents common crashes in apt, top, htop, systemd tools.
  # Content is generic — not tied to any specific device.
  cat >"$PROC_DIR/version"      <<< "Linux version 6.1.0 (builder@termux) (gcc 13) #1 SMP PREEMPT"
  cat >"$PROC_DIR/loadavg"      <<< "0.50 0.50 0.50 1/200 1000"
  cat >"$PROC_DIR/uptime"       <<< "10000.00 20000.00"
  cat >"$PROC_DIR/filesystems"  <<< "nodev	sysfs
nodev	tmpfs
nodev	proc
	ext4
	vfat"
  cat >"$PROC_DIR/cgroups"      <<< "#subsys_name	hierarchy	num_cgroups	enabled
cpu	1	1	1
memory	2	1	1"
  cat >"$PROC_DIR/stat" <<'EOF'
cpu  10000 0 5000 90000 1000 0 0 0 0 0
cpu0 2500 0 1250 22500 250 0 0 0 0 0
cpu1 2500 0 1250 22500 250 0 0 0 0 0
cpu2 2500 0 1250 22500 250 0 0 0 0 0
cpu3 2500 0 1250 22500 250 0 0 0 0 0
intr 0
ctxt 0
btime 1700000000
processes 10000
procs_running 1
procs_blocked 0
EOF
  cat >"$PROC_DIR/vmstat" <<'EOF'
nr_free_pages 100000
nr_inactive_anon 50000
nr_active_anon 80000
nr_inactive_file 30000
nr_active_file 40000
nr_mapped 20000
nr_slab_reclaimable 10000
nr_slab_unreclaimable 5000
pgpgin 0
pgpgout 0
EOF

  # Empty/stub files that some tools check for existence
  for f in buddyinfo consoles crypto devices diskstats execdomains fb \
           interrupts iomem ioports kallsyms key-users keys kpageflags \
           locks misc modules pagetypeinfo partitions sched_debug softirqs \
           timer_list vmallocinfo zoneinfo; do
    : >"$PROC_DIR/$f"
  done
}

# ── Build and exec proot command ─────────────────────────────────────────────
run_proot() {
  unset LD_PRELOAD

  local cmd=(
    proot
    --link2symlink
    --kill-on-exit
    --sysvipc
    -L
    --ashmem-memfd
    -0
    -r "$CONTAINER_DIR"
    -b /dev
    -b /sys
    -b /proc
    -w /root
    -b "$PREFIX/tmp:/tmp"
  )

  # Mount fake proc files over real ones
  for f in "$PROC_DIR"/*; do
    [ -f "$f" ] && cmd+=(--mount="$f:/proc/${f##*/}")
  done

  # Extra args from -e flag
  if [ -n "$EXTRA_ARGS" ]; then
    # shellcheck disable=SC2206
    cmd+=($EXTRA_ARGS)
  fi

  # Command to run
  if [ "$#" -eq 0 ]; then
    if [ -x "$CONTAINER_DIR/bin/su" ]; then
      cmd+=(/bin/su - root)
    else
      cmd+=(/bin/sh)
    fi
  else
    cmd+=("$@")
  fi

  printf '\033[0m'
  exec "${cmd[@]}"
}

# ── CLI ──────────────────────────────────────────────────────────────────────
while [ "$#" -gt 0 ]; do
  case "$1" in
    -r|--root-dir)  CONTAINER_DIR="$2"; shift 2 ;;
    -e|--extra-args) EXTRA_ARGS="$2"; shift 2 ;;
    -b)             EXTRA_ARGS="$EXTRA_ARGS -b $2"; shift 2 ;;
    *)              break ;;
  esac
done

if [ -z "$CONTAINER_DIR" ]; then
  echo "Usage: proot-run -r <container_dir> [-e \"extra args\"] [-b host:guest] [command...]" >&2
  exit 1
fi

setup_proc_files
run_proot "$@"
