#!/bin/sh
# Opt-in download of the Ada -> WebAssembly compiler (D-016).
# Installs AdaWebPack 24 under ${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}.
# Does nothing if that compiler is already there. build.sh never calls this.
# Once, with agreement: sudo apt install rpm2cpio cpio lld libedit2
# alr (Alire) is required only when libgnat-14 is not already installed.
set -e
A=${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}
if [ -x "$A/usr/bin/llvm-gcc" ] && [ -f "$A/lib/libgnat-14.so" ]; then
  echo "AdaWebPack already installed at $A"
  exit 0
fi
mkdir -p "$A/lib"
cd "$A"
F=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Everything/x86_64/os/Packages
for U in \
  https://github.com/godunko/adawebpack/releases/download/24.0.0/adawebpack-24.0.0-git.fc40.x86_64.rpm \
  "$F/l/llvm16-libs-16.0.6-7.fc40.x86_64.rpm" \
  "$F/c/clang16-libs-16.0.6-5.fc40.x86_64.rpm"
do
  echo "Downloading $U"
  curl -fL --retry 3 --retry-delay 2 "$U" | rpm2cpio | cpio -idm --quiet
done
cp usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
if [ ! -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ]; then
  ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
fi
if [ ! -f "$A/lib/libgnat-14.so" ]; then
  if ! ldconfig -p | grep -q libgnat-14.so; then
    command -v alr >/dev/null 2>&1 || {
      echo "alr is required to fetch the GNAT 14 runtime (libgnat-14.so)." >&2
      exit 1
    }
    alr -n install --prefix="$A/gnat14" gnat_native=14.2.1
    cp "$(find "$A/gnat14" -name 'libgnat-14.so' | head -1)" "$A/lib/"
    rm -rf "$A/gnat14"
  fi
fi
rm -rf usr/lib64
echo "Toolchain ready at $A"
