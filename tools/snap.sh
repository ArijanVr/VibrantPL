#!/bin/zsh
# SPDX-FileCopyrightText: 2026 ARJO LAB
# SPDX-License-Identifier: GPL-3.0-or-later

# Renders every screen in light and dark with sample data into /tmp/VibrantPlus-shots.
# Uses a Debug build so SnapshotRunner stays out of Release binaries. The build stays in
# the build folder: taking screenshots must not replace the copy in /Applications.
set -euo pipefail
here=${0:A:h:h}
"$here/build.sh" --debug --no-install
app="$HOME/Library/Developer/VibrantPlus/xcode/Build/Products/Debug/VibrantPlus.app"
data=/tmp/VibrantPlus-snapdata
shots=/tmp/VibrantPlus-shots
rm -rf "$data" "$shots"
APP_DATA=$data "$app/Contents/MacOS/VibrantPlus" --snapshot "$shots"
