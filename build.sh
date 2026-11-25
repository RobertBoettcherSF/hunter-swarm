#!/bin/sh
# Ada sources -> wasm32 -> one self-contained docs/index.html.
# Stops if AdaWebPack is missing. It never downloads the toolchain (D-016).
# Wasm is built with -gnatp (D-027). Contracts stay in the source and run
# in ./run-tests.sh (-gnata).
set -e
cd "$(dirname "$0")"
A=${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}
if [ ! -x "$A/usr/bin/llvm-gcc" ]; then
  echo "AdaWebPack not found at $A." >&2
  echo "After you agree to the download: ./tools/get-toolchain.sh" >&2
  exit 1
fi
export LD_LIBRARY_PATH="$A/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LD=$(command -v wasm-ld || ls /usr/bin/wasm-ld-* | tail -1)
RTS="$A/usr/lib/rts-native"
rm -rf obj/wasm
mkdir -p obj/wasm docs
cd obj/wasm
for F in ../../src/*.adb ../../src/wasm/*.adb; do
  "$A/usr/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2022 -gnatwa -gnatwe -gnatp \
    --RTS="$RTS" -I../../src -I../../src/wasm "$F"
done
ar x "$RTS/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
EXPORTS=$(python3 - << 'PY'
import re, pathlib
text = pathlib.Path("../../src/swarm-api.ads").read_text()
names = re.findall(r'External_Name => "([^"]+)"', text)
print(" ".join(f"--export={name}" for name in names))
PY
)
# shellcheck disable=SC2086
"$LD" --no-entry --allow-undefined --strip-all \
  $EXPORTS --export=memory \
  -z stack-size=1048576 --initial-memory=16777216 \
  -o hs.wasm ./*.o
cd ../..
python3 tools/embed.py obj/wasm/hs.wasm web/template.html docs/index.html docs/version.txt
