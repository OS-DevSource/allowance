#!/bin/zsh
set -eu
cd "${0:A:h}"
configuration=debug
universal=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      configuration=release
      ;;
    --universal)
      universal=true
      ;;
    *)
      print -u2 'Usage: ./build-app.sh [--release] [--universal]'
      exit 2
      ;;
  esac
  shift
done
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
if [[ "${sdk_version%%.*}" -lt 26 ]]; then
  print -u2 'Allowance requires the macOS 26+ SDK (Xcode 26+ or equivalent Command Line Tools).'
  exit 1
fi
build_arguments=(-c "$configuration")
if [[ "$universal" == true ]]; then
  build_arguments+=(--arch arm64 --arch x86_64)
fi
swift build "${build_arguments[@]}"
bin_dir=$(swift build "${build_arguments[@]}" --show-bin-path)
mkdir -p 'Allowance.app/Contents/MacOS' 'Allowance.app/Contents/Resources'
cp "$bin_dir/Allowance" 'Allowance.app/Contents/MacOS/Allowance'
cp Assets/Allowance.icns 'Allowance.app/Contents/Resources/Allowance.icns'
cat > 'Allowance.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Allowance</string>
<key>CFBundleIdentifier</key><string>local.john.allowance</string>
<key>CFBundleExecutable</key><string>Allowance</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.3</string>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundleIconFile</key><string>Allowance.icns</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 John Rodriguez. MIT License.</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
xattr -cr Allowance.app
codesign --force --sign - Allowance.app
codesign --verify Allowance.app
