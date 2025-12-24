#!/bin/bash

set -e

PACKAGE_DIR="./__NAMESPACE__"

if [ ! -d "$PACKAGE_DIR" ]; then
  echo "❌ Package directory not found at $PACKAGE_DIR"
  exit 1
fi

echo "🔍 Validating .meta files in $PACKAGE_DIR..."

missing_meta=0
orphan_meta=0
duplicate_guid=0

declare -A guid_map

###############################################
# Helper: skip tilde folders and their contents
###############################################
should_ignore_dir() {
  local dir="$1"

  # Ignore the package root
  if [ "$dir" = "$PACKAGE_DIR" ]; then
    return 0
  fi

  # Ignore any folder ending with ~
  if [[ "$(basename "$dir")" == *~ ]]; then
    return 0
  fi

  # Ignore anything inside a tilde folder
  if [[ "$dir" == *~/* ]]; then
    return 0
  fi

  return 1
}

###############################################
# 1. Check for missing .meta files (files + dirs)
###############################################

# Files
while IFS= read -r -d '' asset; do
  # Skip files inside tilde folders
  if [[ "$asset" == *~/* ]]; then
    continue
  fi

  if [ ! -f "$asset.meta" ]; then
    echo "❌ Missing meta file: $asset.meta"
    missing_meta=1
  fi
done < <(find "$PACKAGE_DIR" -type f ! -name "*.meta" -print0)

# Directories
while IFS= read -r -d '' dir; do
  if should_ignore_dir "$dir"; then
    continue
  fi

  if [ ! -f "$dir.meta" ]; then
    echo "❌ Missing meta file for directory: $dir.meta"
    missing_meta=1
  fi
done < <(find "$PACKAGE_DIR" -type d -print0)

###############################################
# 2. Check for orphan .meta files
###############################################

while IFS= read -r -d '' meta; do
  asset="${meta%.meta}"

  # Skip metas inside tilde folders
  if [[ "$meta" == *~/* ]]; then
    continue
  fi

  # Skip meta for package root (never exists)
  if [ "$asset" = "$PACKAGE_DIR" ]; then
    continue
  fi

  if [ ! -e "$asset" ]; then
    echo "❌ Orphan meta file: $meta"
    orphan_meta=1
  fi
done < <(find "$PACKAGE_DIR" -type f -name "*.meta" -print0)

###############################################
# 3. Check for duplicate GUIDs
###############################################

while IFS= read -r -d '' meta; do
  # Skip metas inside tilde folders
  if [[ "$meta" == *~/* ]]; then
    continue
  fi

  guid=$(grep -Eo 'guid: [a-f0-9]+' "$meta" | awk '{print $2}')

  if [ -n "$guid" ]; then
    if [[ -n "${guid_map[$guid]}" ]]; then
      echo "❌ Duplicate GUID detected:"
      echo "   $meta"
      echo "   ${guid_map[$guid]}"
      duplicate_guid=1
    else
      guid_map[$guid]="$meta"
    fi
  fi
done < <(find "$PACKAGE_DIR" -type f -name "*.meta" -print0)

###############################################
# Final result
###############################################

if ((missing_meta || orphan_meta || duplicate_guid)); then
  echo "❌ Meta validation failed"
  exit 1
fi

echo "✔ Meta validation passed"
exit 0
