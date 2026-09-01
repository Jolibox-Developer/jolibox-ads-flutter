#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_PATHS=(
  "$ROOT_DIR/README.md"
  "$ROOT_DIR/README_CN.md"
  "$ROOT_DIR/example/README.md"
  "$ROOT_DIR/example/README_CN.md"
  "$ROOT_DIR/example/lib/main.dart"
  "$ROOT_DIR/ios/jolibox_ads_flutter.podspec"
  "$ROOT_DIR/pubspec.yaml"
  "$ROOT_DIR/android/build.gradle"
  "$ROOT_DIR/example/pubspec.yaml"
  "$ROOT_DIR/example/android/settings.gradle"
)

XCFRAMEWORK_DIR="$ROOT_DIR/ios/Frameworks/JoliboxAdMediation.xcframework"

for public_path in "${PUBLIC_PATHS[@]}"; do
  [[ -f "$public_path" ]] || {
    echo "Missing public artifact: $public_path" >&2
    exit 1
  }
done

check_forbidden() {
  local pattern="$1"
  if /usr/bin/grep -E -i -q "$pattern" "${PUBLIC_PATHS[@]}"; then
    echo "Public surface contains an internal configuration, ad unit, or legacy SDK reference." >&2
    exit 1
  fi
}

check_joli_source_value() {
  local matches
  matches=$(/usr/bin/grep -E -i "joliSource[[:space:]]*:[[:space:]]*['\"][^'\"]+['\"]" "${PUBLIC_PATHS[@]}" || true)
  matches=$(printf '%s\n' "$matches" | /usr/bin/grep -v 'YOUR_JOLI_SOURCE' || true)

  if [[ -n "$matches" ]]; then
    echo "Public surface contains a non-placeholder JoliSource value." >&2
    exit 1
  fi
}

check_forbidden_internal_url() {
  local matches
  matches=$(/usr/bin/grep -E -i 'https?://[^[:space:]]*(settings|config|api)[^[:space:]]*' "${PUBLIC_PATHS[@]}" || true)
  matches=$(printf '%s\n' "$matches" | /usr/bin/grep -F -v 'https://storage.googleapis.com/download.flutter.io' || true)

  if [[ -n "$matches" ]]; then
    echo "Public surface contains an internal configuration URL." >&2
    exit 1
  fi
}

check_forbidden 'ca-app-pub-'
check_forbidden_internal_url
check_joli_source_value
check_forbidden 'joli[_-]sdk|jolibox[[:space:]_-]*sdk'

check_forbidden_local_references() {
  local matches

  matches=$(/usr/bin/grep -E -i \
    '(/Users/|/Volumes/|file://|git\.jolibox|https?://[^[:space:]]*(internal|intranet)|(^|[^0-9])(10\.[0-9]+\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.))' \
    "${PUBLIC_PATHS[@]}" || true)
  if [[ -n "$matches" ]]; then
    echo "Public surface contains a local path or internal endpoint." >&2
    exit 1
  fi

  if /usr/bin/grep -E -i -q \
    'dependency_overrides:|mavenLocal\(|flatDir[[:space:]]*\{|implementation[[:space:]]+files\(|\.package\([[:space:]]*path:' \
    "${PUBLIC_PATHS[@]}"; then
    echo "Public surface contains a local dependency declaration." >&2
    exit 1
  fi

  # The repository example intentionally consumes its parent package. Hosts use the released Git Tag.
  matches=$(/usr/bin/grep -E '^[[:space:]]*path:[[:space:]]*' "$ROOT_DIR/example/pubspec.yaml" || true)
  if [[ "$matches" != "    path: ../" ]]; then
    echo "Example local dependency differs from the single allowed parent-package path." >&2
    exit 1
  fi
}

check_xcframework() {
  local candidate
  local matches

  [[ -d "$XCFRAMEWORK_DIR" ]] || {
    echo "Bundled XCFramework is missing." >&2
    exit 1
  }

  if /usr/bin/find "$XCFRAMEWORK_DIR" -type d -name _CodeSignature -print -quit | /usr/bin/grep -q .; then
    echo "Bundled XCFramework contains a stale build-time code signature." >&2
    exit 1
  fi

  while IFS= read -r -d '' candidate; do
    matches=$(/usr/bin/strings "$candidate" | /usr/bin/grep -E '/Users/|/Volumes/|file://|\\/Users\\/|\\/Volumes\\/|file:\\/\\/' || true)
    if [[ -n "$matches" ]]; then
      echo "Bundled XCFramework contains a local build path; matched content is redacted." >&2
      exit 1
    fi
  done < <(/usr/bin/find "$XCFRAMEWORK_DIR" -type f -print0)
}

check_forbidden_local_references
check_xcframework

echo "Public surface check passed."
