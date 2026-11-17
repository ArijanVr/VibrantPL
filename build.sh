#!/bin/zsh
# SPDX-FileCopyrightText: 2026 ARJO LAB
# SPDX-License-Identifier: GPL-3.0-or-later

# Builds Vibrant+ and installs it to /Applications/Vibrant+.app.
# Build products live in ~/Library/Developer/VibrantPlus, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then open the new copy
#        ./build.sh --no-install  build and sign in place, leave /Applications alone (snapshots)
set -euo pipefail
here=${0:A:h}
name="VibrantPlus"
config=release
[[ " $* " == *" --debug "* ]] && config=debug

# Sign with the same Developer ID as the releases, so macOS keeps one set of permissions
# (Screen Recording, Accessibility) for local builds and released copies alike. A permission
# granted to an Apple Development build does not match a Developer ID build and vice versa.
# Fallback: Apple Development, then ad hoc.
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"' || true)
fi
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-

# Developer ID certificates can carry a trusted timestamp, Apple Development ones cannot.
# Asking for one anyway makes codesign fail, which is exactly how broken debug builds
# used to get installed: the error was hidden by `|| true`.
tsflag=--timestamp
if [[ "$identity" == "-" || "$identity" == Apple\ Development:* ]]; then
  tsflag=--timestamp=none
  echo "warning: signing with ${identity}; permissions granted to a Developer ID build do not carry over"
fi

# The app builds as an Xcode project (generated from project.yml with XcodeGen),
# because only xcodebuild extracts the App Intents metadata Siri and Shortcuts need.
derived="$HOME/Library/Developer/$name/xcode"
xconfig=Release
[[ $config == debug ]] && xconfig=Debug
mkdir -p "$here/Generated"
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$here/Generated/Info.plist"
(cd "$here" && xcodegen generate --quiet) || { echo "xcodegen failed"; exit 1; }
log=$(mktemp)
if ! xcodebuild -project "$here/$name.xcodeproj" -scheme "$name" -configuration $xconfig \
     -derivedDataPath "$derived" build >"$log" 2>&1; then
  grep -E "error:" "$log" | sort -u | head -20
  echo "build failed"
  exit 1
fi
grep -E "^/.*warning:" "$log" | sort -u | head -20 || true
built="$derived/Build/Products/$xconfig/$name.app"
[[ -f "$built/Contents/Resources/Metadata.appintents/extract.actionsdata" ]] || echo "warning: no App Intents metadata"

app="/Applications/Vibrant+.app"

# Signs a bundle and proves the result: nested dylibs must carry the app's Team ID or dyld
# refuses to start it. A failed signing is fatal — swallowing it produced apps that crashed
# on launch with "different Team IDs".
sign_app() {
  local target=$1 f nested team
  xattr -cr "$target"
  while IFS= read -r -d "" f; do
    codesign --force --options runtime "$tsflag" --sign "$identity" "$f" || { echo "signing failed: $f"; return 1; }
  done < <(find "$target" -type f \( -name "*.dylib" -o -name "*.so" \) -print0)
  codesign --force --options runtime "$tsflag" --entitlements "$here/VibrantPlus.entitlements" --sign "$identity" "$target" || return 1
  codesign --verify --deep --strict "$target" || { echo "signature check failed"; return 1; }
  team=$(codesign -dvv "$target" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  while IFS= read -r -d "" f; do
    nested=$(codesign -dvv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')
    [[ "$nested" == "$team" ]] || { echo "Team ID mismatch: $f ($nested) vs app ($team)"; return 1; }
  done < <(find "$target" -type f \( -name "*.dylib" -o -name "*.so" \) -print0)
}

# --no-install leaves /Applications alone (snapshots and quick checks). The build product is
# signed in place, so it can be started from there.
if [[ " $* " == *" --no-install "* ]]; then
  sign_app "$built" || exit 1
  echo "built $built (signed: ${identity})"
  exit 0
fi

# The running copy, as a regular expression: the + in Vibrant+ is escaped, and pgrep never
# matches itself (an awk over `ps` did, which made every build kill a finished app twice).
running_pids() { pgrep -f -- "Vibrant[+]\.app/Contents/MacOS/VibrantPlus"; }

# Quit the running copy and wait until it is gone. Replacing the bundle under a live
# process leaves its code pages pointing at deleted files; the next page-in kills it
# with SIGBUS (KERN_MEMORY_ERROR).
if [[ -n "$(running_pids)" ]]; then
  echo "quitting the running copy"
  osascript -e 'tell application id "ch.arjo.vibrantplus" to quit' >/dev/null 2>&1 || true
  for _ in {1..50}; do
    [[ -z "$(running_pids)" ]] && break
    sleep 0.1
  done
  stale=$(running_pids || true)
  if [[ -n "$stale" ]]; then
    echo "warning: Vibrant+ did not quit, stopping it"
    kill $stale 2>/dev/null || true
    sleep 0.3
  fi
fi

rm -rf "$app"
ditto "$built" "$app"
sign_app "$app" || exit 1
echo "installed $app (signed: ${identity})"

if [[ " $* " == *" --open "* ]]; then
  open "$app"
fi
