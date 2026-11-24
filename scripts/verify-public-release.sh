#!/bin/bash
# Verify the existing public v0.1.4 release without installing or launching it.
set -euo pipefail
work="$(mktemp -d "${TMPDIR:-/tmp}/allowance-verify.XXXXXX")"
mount="$work/mounted"
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then
    if ! hdiutil detach "$mount" -quiet; then
      printf 'Could not detach %s; audit files retained.\n' "$mount" >&2
      return 1
    fi
  fi
  rm -rf "$work"
}
trap cleanup EXIT
cd "$work"
base=https://github.com/OS-DevSource/allowance/releases/download/v0.1.4
dmg=Allowance-macOS-universal.dmg
zip=Allowance-macOS-universal.zip
for file in "$dmg" "$zip" "$dmg.sha256" "$zip.sha256"; do
  curl --fail --location --silent --show-error --retry 2 --max-time 120 "$base/$file" -o "$file"
done
verify_hash() {
  local file="$1" expected="$2" actual sidecar
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  sidecar="$(awk 'NR == 1 {print $1} END {if (NR != 1) exit 1}' "$file.sha256")"
  [[ "$actual" == "$expected" && "$sidecar" == "$expected" ]]
  printf '%s: SHA-256 verified\n' "$file"
}
verify_hash "$dmg" 14c2bad61a1ef0ba2683260bd2df44394007cb0bc9b0daf5c0c79abe861f2424
verify_hash "$zip" 93c2e354bd4843392679877535082ff456fd16db0cb13cafc52d307eb498cf0d
hdiutil verify "$dmg"
unzip -tq "$zip"
mkdir -p "$mount" "$work/extracted"
hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mount"
mounted=1
ditto -x -k "$zip" "$work/extracted"
[[ -L "$mount/Applications" && "$(readlink "$mount/Applications")" == /Applications ]]
for app in "$mount/Allowance.app" "$work/extracted/Allowance.app"; do
  plist="$app/Contents/Info.plist"
  bin="$app/Contents/MacOS/Allowance"
  plutil -lint "$plist"
  [[ "$(plutil -extract CFBundleShortVersionString raw "$plist")" == 0.1.4 ]]
  [[ "$(plutil -extract CFBundleVersion raw "$plist")" == 6 ]]
  [[ "$(plutil -extract CFBundleIdentifier raw "$plist")" == local.john.allowance ]]
  [[ "$(plutil -extract LSMinimumSystemVersion raw "$plist")" == 13.0 ]]
  lipo -verify_arch arm64 x86_64 "$bin"
  codesign --verify --strict --verbose=2 "$app"
done
cmp "$mount/Allowance.app/Contents/MacOS/Allowance" "$work/extracted/Allowance.app/Contents/MacOS/Allowance"
cmp "$mount/Allowance.app/Contents/Info.plist" "$work/extracted/Allowance.app/Contents/Info.plist"
hdiutil detach "$mount" -quiet
mounted=0
printf 'Public v0.1.4 package verification passed. Installation and live CLI checks remain separate.\n'
