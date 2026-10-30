#!/bin/sh
# Builds Keyper for a generic iPhone in Release (optimised, unsigned) and checks the binary:
# - memset_s is linked, so the wipes in SecureZero survived the optimiser;
# - none of the Debug-only test hooks made it in.
# Usage, from app-ios: scripts/check-release.sh [derived-data-dir]
set -eu
dd=${1:-build/release-check}
xcodebuild -project Keyper.xcodeproj -scheme Keyper -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$dd" CODE_SIGNING_ALLOWED=NO build >/dev/null
bin="$dd/Build/Products/Release-iphoneos/Keyper.app/Keyper"
fail=0
if nm -u "$bin" | grep -qx '_memset_s'; then
  echo "ok: memset_s is linked"
else
  echo "FAIL: memset_s is not linked; the wipes may have been optimised away"; fail=1
fi
for hook in KeyperAllowScreenshots KeyperSimulateOffline KeyperClipboardSeconds KeyperBench KeyperInterfaces pasteboard_state PasteboardProbe DeviceBench KEYPER-BENCH KEYPER-IF; do
  if strings -a "$bin" | grep -q "$hook"; then
    echo "FAIL: test hook $hook is in the Release binary"; fail=1
  fi
done
[ $fail -eq 0 ] && echo "ok: no test hooks in the Release binary"
exit $fail
