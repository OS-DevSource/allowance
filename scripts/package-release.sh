#!/bin/zsh
set -eu

repo_root="${0:A:h:h}"
cd "$repo_root"

output_dir="${1:-dist}"
if [[ "$output_dir" != /* ]]; then
  output_dir="$repo_root/$output_dir"
fi

archive_name='Allowance-macOS-universal.zip'
checksum_name="$archive_name.sha256"
archive_path="$output_dir/$archive_name"
checksum_path="$output_dir/$checksum_name"

./build-app.sh --release --universal

binary_path='Allowance.app/Contents/MacOS/Allowance'
lipo -verify_arch arm64 "$binary_path"
lipo -verify_arch x86_64 "$binary_path"
codesign --verify --strict Allowance.app
plutil -lint Allowance.app/Contents/Info.plist

mkdir -p "$output_dir"
rm -f "$archive_path" "$checksum_path"
ditto -c -k --sequesterRsrc --keepParent Allowance.app "$archive_path"

(
  cd "$output_dir"
  shasum -a 256 "$archive_name" > "$checksum_name"
)

print "Created $archive_path"
print "Created $checksum_path"
