#!/bin/zsh
set -eu

repo_root="${0:A:h:h}"
cd "$repo_root"

output_dir="${1:-dist}"
if [[ "$output_dir" != /* ]]; then
  output_dir="$repo_root/$output_dir"
fi

archive_name='Allowance-macOS-universal.zip'
dmg_name='Allowance-macOS-universal.dmg'
archive_checksum_name="$archive_name.sha256"
dmg_checksum_name="$dmg_name.sha256"
archive_path="$output_dir/$archive_name"
dmg_path="$output_dir/$dmg_name"
archive_checksum_path="$output_dir/$archive_checksum_name"
dmg_checksum_path="$output_dir/$dmg_checksum_name"
dmg_layout_path='Assets/DMG/layout.dsstore'
dmg_staging_dir=$(mktemp -d /tmp/allowance-dmg-stage.XXXXXX)
dmg_mount_dir=$(mktemp -d /tmp/allowance-dmg-mount.XXXXXX)
dmg_is_mounted=false

cleanup() {
  if [[ "$dmg_is_mounted" == true ]]; then
    hdiutil detach "$dmg_mount_dir" -quiet || true
  fi
  if [[ "$dmg_staging_dir" == /tmp/allowance-dmg-stage.* ]]; then
    rm -rf "$dmg_staging_dir"
  fi
  if [[ "$dmg_mount_dir" == /tmp/allowance-dmg-mount.* ]]; then
    rmdir "$dmg_mount_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT

./build-app.sh --release --universal

binary_path='Allowance.app/Contents/MacOS/Allowance'
lipo -verify_arch arm64 "$binary_path"
lipo -verify_arch x86_64 "$binary_path"
codesign --verify --strict Allowance.app
plutil -lint Allowance.app/Contents/Info.plist

mkdir -p "$output_dir"
rm -f "$archive_path" "$dmg_path" "$archive_checksum_path" "$dmg_checksum_path"
ditto -c -k --sequesterRsrc --keepParent Allowance.app "$archive_path"

ditto Allowance.app "$dmg_staging_dir/Allowance.app"
xattr -cr "$dmg_staging_dir/Allowance.app"
codesign --verify --strict "$dmg_staging_dir/Allowance.app"
ln -s /Applications "$dmg_staging_dir/Applications"
cp Assets/Allowance.icns "$dmg_staging_dir/.VolumeIcon.icns"
cp "$dmg_layout_path" "$dmg_staging_dir/.DS_Store"
SetFile -a C "$dmg_staging_dir"
hdiutil create -quiet -volname Allowance -srcfolder "$dmg_staging_dir" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$dmg_path"
hdiutil verify "$dmg_path" >/dev/null

hdiutil attach -quiet -readonly -nobrowse -mountpoint "$dmg_mount_dir" "$dmg_path"
dmg_is_mounted=true
[[ -d "$dmg_mount_dir/Allowance.app" ]]
[[ -L "$dmg_mount_dir/Applications" ]]
[[ "$(readlink "$dmg_mount_dir/Applications")" == '/Applications' ]]
cmp Assets/Allowance.icns "$dmg_mount_dir/.VolumeIcon.icns"
cmp "$dmg_layout_path" "$dmg_mount_dir/.DS_Store"
mounted_binary_path="$dmg_mount_dir/Allowance.app/Contents/MacOS/Allowance"
lipo -verify_arch arm64 "$mounted_binary_path"
lipo -verify_arch x86_64 "$mounted_binary_path"
codesign --verify --strict "$dmg_mount_dir/Allowance.app"
[[ "$(plutil -extract CFBundleShortVersionString raw "$dmg_mount_dir/Allowance.app/Contents/Info.plist")" == '0.1.3' ]]
hdiutil detach "$dmg_mount_dir" -quiet
dmg_is_mounted=false

(
  cd "$output_dir"
  shasum -a 256 "$archive_name" > "$archive_checksum_name"
  shasum -a 256 "$dmg_name" > "$dmg_checksum_name"
)

print "Created $archive_path"
print "Created $archive_checksum_path"
print "Created $dmg_path"
print "Created $dmg_checksum_path"
