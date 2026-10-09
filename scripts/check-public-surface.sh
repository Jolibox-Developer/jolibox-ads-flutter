#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check the index so accidentally staged workspace documents block publication.
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  internal_documents=$(git -C "$ROOT_DIR" ls-files --cached -- \
    project-specs AGENTS.md CLAUDE.md teamwork-space.md .teamwork-local-env)
  if [[ -n "$internal_documents" ]]; then
    echo "Internal workspace documents must not be tracked in this public repository." >&2
    exit 1
  fi
fi

PUBLIC_PATHS=(
  "$ROOT_DIR/README.md"
  "$ROOT_DIR/README_CN.md"
  "$ROOT_DIR/pubspec.yaml"
  "$ROOT_DIR/native/android/build.gradle"
  "$ROOT_DIR/JoliboxFlutterAdsBridgeAdMob.podspec"
  "$ROOT_DIR/examples/native_channels/flutter_module/pubspec.yaml"
  "$ROOT_DIR/examples/native_channels/android_host/app/build.gradle"
  "$ROOT_DIR/examples/native_channels/ios_host/Podfile"
  "$ROOT_DIR/maven/README.md"
  "$ROOT_DIR/maven/com/jolibox/admediation/jolibox-ads-flutter-bridge-admob/0.8.0/jolibox-ads-flutter-bridge-admob-0.8.0.pom"
  "$ROOT_DIR/maven/com/jolibox/admediation/jolibox-ads-flutter-bridge-admob/0.8.0/jolibox-ads-flutter-bridge-admob-0.8.0.module"
)
XCFRAMEWORK_DIR="$ROOT_DIR/native/ios/Frameworks/JoliboxAdMediation.xcframework"

for public_path in "${PUBLIC_PATHS[@]}"; do
  [[ -f "$public_path" ]] || {
    echo "Missing public artifact: $public_path" >&2
    exit 1
  }
done

if /usr/bin/grep -E -i -q \
  '(ca-app-pub-|/Users/|/Volumes/|file://|git\.jolibox|https?://[^[:space:]]*(internal|intranet)|(^|[^0-9])(10\.[0-9]+\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.))' \
  "${PUBLIC_PATHS[@]}"; then
  echo "Public surface contains a credential, local path, or internal endpoint." >&2
  exit 1
fi

source_values=$(/usr/bin/grep -E -i "joliSource[[:space:]]*:[[:space:]]*['\"][^'\"]+['\"]" \
  "${PUBLIC_PATHS[@]}" || true)
source_values=$(printf '%s\n' "$source_values" | /usr/bin/grep -v 'YOUR_JOLI_SOURCE' || true)
if [[ -n "$source_values" ]]; then
  echo "Public surface contains a non-placeholder JoliSource value." >&2
  exit 1
fi

if /usr/bin/grep -E -i -q \
  'dependency_overrides:|^[[:space:]]*plugin:|jolibox_ads_flutter_admob|Google-Mobile-Ads-SDK|jolibox-ad-mediation' \
  "$ROOT_DIR/pubspec.yaml" "$ROOT_DIR/examples/native_channels/flutter_module/pubspec.yaml"; then
  echo "The shared Flutter dependency graph contains a native ad plugin." >&2
  exit 1
fi

[[ ! -d "$ROOT_DIR/android" && ! -d "$ROOT_DIR/ios" ]] || {
  echo "The base Dart package must not contain native ad directories." >&2
  exit 1
}

/usr/bin/grep -F -q 'jolibox-ad-mediation:0.6.2' "$ROOT_DIR/native/android/build.gradle" || {
  echo "Android adapter is missing its mediation dependency." >&2
  exit 1
}
/usr/bin/grep -F -q "s.dependency 'Google-Mobile-Ads-SDK', '12.1.0'" \
  "$ROOT_DIR/JoliboxFlutterAdsBridgeAdMob.podspec" || {
  echo "iOS adapter is missing its Google Ads dependency." >&2
  exit 1
}
/usr/bin/grep -F -q 'admobImplementation project(":adBridge")' \
  "$ROOT_DIR/examples/native_channels/android_host/app/build.gradle" || {
  echo "Android native host lost its ads-only dependency." >&2
  exit 1
}
if /usr/bin/grep -F -q 'baseImplementation project(":adBridge")' \
  "$ROOT_DIR/examples/native_channels/android_host/app/build.gradle"; then
  echo "Android base variant depends on the ad bridge." >&2
  exit 1
fi

[[ -d "$XCFRAMEWORK_DIR" ]] || {
  echo "Jolibox XCFramework is missing." >&2
  exit 1
}
if /usr/bin/find "$XCFRAMEWORK_DIR" -type d -name _CodeSignature -print -quit | /usr/bin/grep -q .; then
  echo "Jolibox XCFramework contains a stale code signature." >&2
  exit 1
fi

while IFS= read -r -d '' candidate; do
  local_paths=$(/usr/bin/strings "$candidate" |
    /usr/bin/grep -E '/Users/|/Volumes/|file://|\\/Users\\/|\\/Volumes\\/|file:\\/\\/' || true)
  if [[ -n "$local_paths" ]]; then
    echo "Jolibox XCFramework contains a local build path; matched content is redacted." >&2
    exit 1
  fi
done < <(/usr/bin/find "$XCFRAMEWORK_DIR" -type f -print0)

while IFS= read -r -d '' candidate; do
  if /usr/bin/nm -m "$candidate" 2>/dev/null |
      /usr/bin/grep 'external _OBJC_CLASS_\$_GAD' |
      /usr/bin/grep -v '(undefined)' | /usr/bin/grep -q .; then
    echo "Jolibox XCFramework defines Google Mobile Ads Objective-C classes." >&2
    exit 1
  fi
done < <(/usr/bin/find "$XCFRAMEWORK_DIR" -type f -name JoliboxAdMediation -print0)

echo "Public surface check passed."
