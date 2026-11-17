#!/bin/zsh
# SPDX-FileCopyrightText: 2026 ARJO LAB
# SPDX-License-Identifier: GPL-3.0-or-later

# Renders every screen in light and dark with sample data into /tmp/VibrantPlus-shots.
# Uses a Debug build so SnapshotRunner stays out of Release binaries.
set -euo pipefail
here=${0:A:h:h}
"$here/build.sh" --debug
data=/tmp/VibrantPlus-snapdata
shots=/tmp/VibrantPlus-shots
rm -rf "$data" "$shots"
APP_DATA=$data "/Applications/Vibrant+.app/Contents/MacOS/VibrantPlus" --snapshot "$shots"
