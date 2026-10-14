#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
xcodebuild -project AutoSignStore.xcodeproj -scheme AutoSignStore \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData/Device CODE_SIGNING_ALLOWED=NO build
mkdir -p dist
package_dir="$(mktemp -d "${TMPDIR:-/tmp}/autosign-store-package.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
/usr/bin/ditto DerivedData/Device/Build/Products/Release-iphoneos/AutoSignStore.app "$package_dir/Payload/AutoSignStore.app"
/usr/bin/ditto -c -k --keepParent "$package_dir/Payload" dist/AutoSignStore.ipa
echo "已生成待 AutoSign 签名的 IPA：$project_dir/dist/AutoSignStore.ipa"
