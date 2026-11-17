#!/bin/zsh
# SPDX-FileCopyrightText: 2026 ARJO LAB
# SPDX-License-Identifier: GPL-3.0-or-later

# Vibrant+ Release: Developer-ID sign, notarize, staple, ZIP.
# Destination: set PROJEKTELAB_RELEASES to your local Releases folder.
# Usage: tools/release.sh          build, sign, notarize, store
#         tools/release.sh --pfad   print destination only
# Once: xcrun notarytool store-credentials "$NOTARY_PROFILE" --apple-id … --team-id …
set -euo pipefail
here=${0:A:h:h}
releases=${PROJEKTELAB_RELEASES:?"Set PROJEKTELAB_RELEASES to your local Releases folder"}
[[ -d $releases ]] || { echo "Releases folder missing: $releases" >&2; exit 1; }
ziel() { local v=$1; while [[ ${#v//[^.]/} -lt 2 ]]; do v="$v.0"; done; local base="$releases/$(date +%Y-%m-%d)_v$v" d n=2; d=$base; while [[ -e $d ]]; do d="${base}_$n"; n=$((n+1)); done; print -r -- "$d/Dateien/$2"; }

if [[ ${1:-} == --pfad ]]; then
  version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$here/Info.plist.in")
  echo "Ziel: $(ziel "$version" macOS)/Vibrant+-$version.zip"; exit 0
fi

"$here/build.sh"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "/Applications/Vibrant+.app/Contents/Info.plist")
dir=$(ziel "$version" macOS)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
ditto "/Applications/Vibrant+.app" "$work/Vibrant+.app"
identity=${SIGN_IDENTITY:?"Set SIGN_IDENTITY, e.g. Developer ID Application: …"}
profile=${NOTARY_PROFILE:?"Set NOTARY_PROFILE to your notarytool keychain profile name"}
codesign --force --options runtime --timestamp --entitlements "$here/VibrantPlus.entitlements" \
  --sign "$identity" "$work/Vibrant+.app"
ditto -c -k --keepParent "$work/Vibrant+.app" "$work/upload.zip"
xcrun notarytool submit "$work/upload.zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$work/Vibrant+.app"
spctl -a -vv "$work/Vibrant+.app"
mkdir -p "$dir"
ditto -c -k --keepParent "$work/Vibrant+.app" "$dir/Vibrant+-$version.zip"
echo "release: $dir/Vibrant+-$version.zip (notarisiert)"
releases_repo=${GITHUB_RELEASES_REPO:-ArijanVr/VibrantPlus}
if command -v gh >/dev/null; then
  zip="$dir/Vibrant+-$version.zip"
  tag="v$version"
  if gh release view "$tag" --repo "$releases_repo" >/dev/null 2>&1; then
    gh release upload "$tag" "$zip" --repo "$releases_repo" --clobber && echo "github: $releases_repo $tag" || echo "github: Upload fehlgeschlagen, ZIP liegt in $dir"
  else
    gh release create "$tag" "$zip" --repo "$releases_repo" --title "Vibrant+ $version" --notes "Notarisiertes ZIP. GPL-3.0-or-later. Neuinstallation statt Update von 1.0.x." && echo "github: $releases_repo $tag" || echo "github: Anlegen fehlgeschlagen, ZIP liegt in $dir"
  fi
else
  echo "Hinweis: gh fehlt — ZIP manuell unter https://github.com/ArijanVr/VibrantPlus/releases hochladen."
fi
