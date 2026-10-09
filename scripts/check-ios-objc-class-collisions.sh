#!/bin/zsh
set -euo pipefail

APP_BUNDLE="${1:?Usage: $0 /path/to/Your.app}"
REPORT_PATH=$(mktemp "${TMPDIR:-/tmp}/jolibox-objc-classes.XXXXXX")
trap 'rm -f "$REPORT_PATH"' EXIT

[[ -d "$APP_BUNDLE" ]] || {
  echo "App bundle is missing: $APP_BUNDLE" >&2
  exit 1
}
collect_classes() {
  local binary="$1"
  local architectures
  local architecture

  architectures=$(lipo -archs "$binary" 2>/dev/null || true)
  if [[ " $architectures " == *" arm64 "* ]]; then
    architecture="arm64"
  else
    architecture="${architectures%% *}"
  fi
  [[ -n "$architecture" ]] || return

  nm -arch "$architecture" -m "$binary" 2>/dev/null |
    grep 'external _OBJC_CLASS_\$_' |
    grep -v '(undefined)' |
    sed -n 's/.*external _OBJC_CLASS_\$_\([A-Za-z0-9_]*\).*/\1/p' |
    while IFS= read -r class_name; do
      printf '%s\t%s\n' "$class_name" "$binary" >> "$REPORT_PATH"
    done
}

while IFS= read -r -d '' candidate; do
  file "$candidate" | grep -q 'Mach-O' || continue
  collect_classes "$candidate"
done < <(find "$APP_BUNDLE" -type f -print0)

[[ -s "$REPORT_PATH" ]] || {
  echo "No Objective-C class definitions found in ${APP_BUNDLE:t}." >&2
  exit 1
}

duplicate_classes=$(cut -f 1 "$REPORT_PATH" | sort | uniq -d)
if [[ -n "$duplicate_classes" ]]; then
  echo "Objective-C classes are defined by more than one binary:" >&2
  while IFS= read -r class_name; do
    print -r -- "  $class_name" >&2
    grep -F -- "${class_name}"$'\t' "$REPORT_PATH" | cut -f 2- | sort -u | sed 's/^/    /' >&2
  done <<< "$duplicate_classes"
  exit 1
fi

echo "No duplicate Objective-C class definitions in ${APP_BUNDLE:t}."
