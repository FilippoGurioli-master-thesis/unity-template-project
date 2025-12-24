#!/bin/bash

set -e

SAMPLES_DIR="./__NAMESPACE__/Samples~"

if [ ! -d "$SAMPLES_DIR" ]; then
  echo "✔ No Samples~ folder found — skipping sample validation"
  exit 0
fi

echo "🔍 Validating sample scenes in $SAMPLES_DIR..."

missing_scripts=0
missing_prefabs=0
missing_materials=0
missing_guid=0
external_guid=0

###############################################
# Helper: check if GUID exists inside Package/
###############################################
guid_exists() {
  local guid="$1"
  if find ./Package -type f -name "*.meta" -exec grep -q "guid: $guid" {} \; 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

###############################################
# Scan all .unity scenes inside Samples~
###############################################
while IFS= read -r -d '' scene; do
  echo "  • Checking $(basename "$scene")"

  # 1. Missing scripts
  if grep -q "m_Script: {fileID: 0" "$scene"; then
    echo "❌ Missing script in scene: $scene"
    missing_scripts=1
  fi

  # 2. Missing prefabs
  if grep -q "m_CorrespondingSourceObject: {fileID: 0" "$scene"; then
    echo "❌ Missing prefab in scene: $scene"
    missing_prefabs=1
  fi

  # 3. Missing materials
  if grep -q "m_Material: {fileID: 0" "$scene"; then
    echo "❌ Missing material in scene: $scene"
    missing_materials=1
  fi

  # 4 & 5. GUID validation
  while read -r guid; do
    # Skip empty GUIDs
    if [ -z "$guid" ]; then
      continue
    fi

    # Check if GUID exists inside the package
    if ! guid_exists "$guid"; then
      echo "❌ Scene references missing or external GUID: $guid"
      echo "   in scene: $scene"
      missing_guid=1
    fi

  done < <(grep -Eo "guid: [a-f0-9]{32}" "$scene" | awk '{print $2}')

done < <(find "$SAMPLES_DIR" -type f -name "*.unity" -print0)

###############################################
# Final result
###############################################

if ((missing_scripts || missing_prefabs || missing_materials || missing_guid)); then
  echo "❌ Sample scene validation failed"
  exit 1
fi

echo "✔ Sample scene validation passed"
exit 0
