#!/bin/sh
# Native smoke. Contracts are on (-gnata). Warnings fail the build (D-015).
# GNAT 12 is the laptop compiler. gnatmake-12 is accepted when gnatmake is absent.
set -e
cd "$(dirname "$0")"
if [ -n "${GNATMAKE:-}" ]; then
  GM=$GNATMAKE
elif command -v gnatmake >/dev/null 2>&1; then
  GM=gnatmake
elif command -v gnatmake-12 >/dev/null 2>&1; then
  GM=gnatmake-12
else
  echo "gnatmake (GNAT 12) not found" >&2
  exit 1
fi
mkdir -p obj/native
"$GM" -gnat2022 -gnata -gnatwa -gnatwe -O1 \
  -D obj/native -Isrc tests/smoke.adb -o obj/native/smoke \
  -bargs -static
if ldd obj/native/smoke | grep -q libgnat; then
  echo "libgnat is dynamically linked" >&2
  exit 1
fi
./obj/native/smoke
