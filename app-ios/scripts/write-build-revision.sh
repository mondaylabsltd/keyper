#!/bin/sh
# An always-run Xcode phase: HEAD, tracked edits and untracked sources all affect the label.
set -eu
repo="$SRCROOT/.."
revision=$(/usr/bin/git -C "$repo" rev-parse --short=12 HEAD)
if [ -n "$(/usr/bin/git -C "$repo" status --porcelain --untracked-files=normal)" ]; then
  revision="$revision-dirty"
fi
mkdir -p "$(dirname "$SCRIPT_OUTPUT_FILE_0")"
printf '%s\n' "$revision" > "$SCRIPT_OUTPUT_FILE_0"
