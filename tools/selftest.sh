#!/bin/zsh
# Runs the in-app self-test against a fresh folder in /tmp. Exit code 0 when every check passed.
# Expects a Release-signed app at /Applications (./build.sh).
set -u
data=/tmp/VibrantPlus-selftest
rm -rf $data
APP_DATA=$data APP_CLAUDE_SETTINGS=$data/claude/settings.json "/Applications/Vibrant+.app/Contents/MacOS/VibrantPlus" --selftest
