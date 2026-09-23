#!/usr/bin/env bash
#
# Build the Soarer's Converter tools (scas, scdis, sctool) for macOS.
#
#   scas    assembles a .sc config file into the .scb binary the converter eats
#   scdis   disassembles a .scb back into .sc text
#   sctool  talks to the converter over raw HID (info/listen/read/write)
#
# Source: https://github.com/thentenaar/sctools (BSD-2-Clause).
# No Homebrew / autotools needed: scas+scdis are plain C, and sctool is built
# against the bundled hidapi macOS backend (IOKit) directly.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/vendor/.build/sctools"
BIN="$HERE/vendor/bin"
CC="${CC:-clang}"
CFLAGS="${CFLAGS:--O2}"

mkdir -p "$BIN" "$(dirname "$SRC")"

if [ ! -d "$SRC/src" ]; then
  echo "==> fetching sctools source"
  git clone --depth 1 --recursive https://github.com/thentenaar/sctools.git "$SRC"
fi

# Two scdis fixes for macro blocks:
#  - a macro with no meta match condition (e.g. a plain `macro F10`) aborted
#    disassembly; emit an empty match string instead.
#  - get_macrostep_metas() read past the 4-entry `metas[]` array for the high
#    meta bits, injecting garbage bytes (e.g. 0x03) whenever a step held both
#    shift and gui (the SHIFT GUI from a screenshot macro); split pairs and
#    use the 8-entry hmetas[].
PATCH="$HERE/vendor/patches/scdis-macro-empty-meta.patch"
if [ -f "$PATCH" ] && git -C "$SRC" apply --check "$PATCH" >/dev/null 2>&1; then
  echo "==> applying scdis macro patches"
  git -C "$SRC" apply "$PATCH"
fi

echo "==> building scas, scdis, sctool"
"$CC" $CFLAGS -o "$BIN/scas"  "$SRC/src/scas.c"  "$SRC/src/hid_tokens.c" "$SRC/src/macro_tokens.c"
"$CC" $CFLAGS -o "$BIN/scdis" "$SRC/src/scdis.c" "$SRC/src/hid_tokens.c" "$SRC/src/macro_tokens.c"
"$CC" $CFLAGS -o "$BIN/sctool" \
  "$SRC/src/sctool.c" "$SRC/src/commands.c" "$SRC/src/hid_tokens.c" \
  "$SRC/hidapi/mac/hid.c" \
  -I"$SRC/hidapi" -I"$SRC/hidapi/hidapi" \
  -framework IOKit -framework CoreFoundation -framework AppKit

# arm64 macOS refuses to exec unsigned binaries; ad-hoc sign them.
codesign -s - -f "$BIN/scas" "$BIN/scdis" "$BIN/sctool" >/dev/null 2>&1 || true

echo "==> done"
ls -l "$BIN"
