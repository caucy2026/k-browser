#!/bin/sh

set -eu

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

OS=$(uname -s)
ARCH=$(uname -m)

[ "$OS" = "Linux" ] || fail "Chromium Android build host must be Linux; current host is $OS"
[ "$ARCH" = "x86_64" ] || fail "Chromium Android build host must be x86_64; current host is $ARCH"

for TOOL in git python3 curl; do
  command -v "$TOOL" >/dev/null 2>&1 || fail "$TOOL is missing"
done

MEM_KB=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
DISK_KB=$(df -Pk . | awk 'NR == 2 {print $4}')

[ "$MEM_KB" -ge 16000000 ] || fail "at least 16 GB RAM is required"
[ "$DISK_KB" -ge 157286400 ] || fail "at least 150 GB free disk is required"

echo "Host: $OS $ARCH"
echo "RAM: $((MEM_KB / 1024)) MB"
echo "Free disk: $((DISK_KB / 1024 / 1024)) GB"
echo "BUILD HOST CHECK PASSED"
