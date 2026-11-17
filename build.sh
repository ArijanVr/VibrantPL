#!/bin/zsh
# SPDX-FileCopyrightText: 2026 ARJO LAB
# SPDX-License-Identifier: GPL-3.0-or-later

# Builds Vibrant+ and installs it to /Applications/Vibrant+.app.
# Build products live in ~/Library/Developer/VibrantPlus, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then quit the running copy and open the new one
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
rm -rf "$app"
ditto "$built" "$app"
xattr -cr "$app"
# Nested debug dylibs must match the app Team ID or dyld rejects them.
find "$app" -type f \( -name "*.dylib" -o -name "*.so" \) -print0 2>/dev/null | while IFS= read -r -d "" f; do
  codesign --force --options runtime --timestamp --sign "$identity" "$f" 2>/dev/null || true
done
codesign --force --options runtime --timestamp=none --entitlements "$here/VibrantPlus.entitlements" --sign "$identity" "$app" 2>&1 | grep -v "replacing existing signature" || true
echo "installed $app (signed: ${identity})"

if [[ " $* " == *" --open "* ]]; then
  osascript -e "quit app id \"ch.arjo.vibrantplus\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
