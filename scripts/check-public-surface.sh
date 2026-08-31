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
)

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

echo "Public surface check passed."
