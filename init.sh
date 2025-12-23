#!/bin/bash

# helper functions

askWithDefault() {
  local prompt="$1"
  local default="$2"
  local input

  read -r -p "$prompt [default: $default]: " input
  if [[ -n "$input" ]]; then
    printf '%s\n' "$input"
    return 0
  else
    printf '%s\n' "$default"
    return 0
  fi
}

askNonNull() {
  local prompt="$1"
  local input

  while true; do
    read -r -p "$prompt: " input
    if [[ -n "$input" ]]; then
      printf '%s\n' "$input"
      return 0
    else
      printf 'Warning: value cannot be empty. Please try again.\n' >&2
    fi
  done
}

kebabToPascal() {
  local input="$1"
  local output=""
  local part

  IFS='-' read -ra parts <<<"$input"

  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    output+="${part^}"
  done

  printf '%s\n' "$output"
}

replaceInFiles() {
  local search="$1"
  local replace="$2"
  local self

  self="./$(basename "${BASH_SOURCE[0]}")"

  find . \
    -type d -name .git -prune -o \
    -type f ! -path "$self" -print0 |
    xargs -0 grep -Il "$search" |
    xargs sed -i "s/${search//\//\\/}/${replace//\//\\/}/g"
}

renameFiles() {
  local search="$1"
  local replace="$2"

  find . -type f -print0 | while IFS= read -r -d '' file; do
    local dirname
    local basename
    local newname

    basename="$(basename "$file")"
    dirname="$(dirname "$file")"

    if [[ "$basename" == *"$search"* ]]; then
      newname="${basename//$search/$replace}"
      mv "$file" "$dirname/$newname" 2>/dev/null
    fi
  done
}

firstMatch() {
  local pattern="$1"
  set -- $pattern
  if [ "$1" = "$pattern" ]; then
    return 1 # no match
  fi
  printf '%s\n' "$1"
  return 0
}

# Read customer values

DOMAIN=$(askWithDefault "Enter the top level domain" "com")
COMPANY=$(askNonNull "Enter your company name (e.g. 'mycompany')")
PACKAGE=$(askNonNull "Enter your package name (e.g. 'awesome-tool')")
NAMESPACE=$(askWithDefault "Enter the default namespace" $(kebabToPascal $PACKAGE))

echo "The resulting package unique ID is $DOMAIN.$COMPANY.$PACKAGE"
echo "The namespace is $NAMESPACE"

# Replace words in all files
replaceInFiles "__DOMAIN__" $DOMAIN
replaceInFiles "__COMPANY__" $COMPANY
replaceInFiles "__PACKAGE__" $PACKAGE
replaceInFiles "__NAMESPACE__" $NAMESPACE

# Rename all files with matching pattern
renameFiles "__DOMAIN__" $DOMAIN
renameFiles "__COMPANY__" $COMPANY
renameFiles "__PACKAGE__" $PACKAGE
renameFiles "__NAMESPACE__" $NAMESPACE

# Create a unity project that uses this package
UNITY_HUB_PATH="$HOME/Unity/Hub/Editor"
UNITY_PATH=$(find "$UNITY_HUB_PATH" -maxdepth 1 -type d -name "6000*" | sort -V | head -n1)/Editor/Unity
PROJECT_PATH="$(pwd)/../${NAMESPACE}.TestProject"

"$UNITY_PATH" \
  -createProject "$PROJECT_PATH" \
  -batchmode \
  -quit \
  -logFile "-"

# Configure the project to link this package
PACKAGE_NAME="$DOMAIN.$COMPANY.$PACKAGE"
PACKAGE_PATH="file:../unity-package-template"
MANIFEST="$PROJECT_PATH/Packages/manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest.json not found in $PROJECT_PATH/Packages" >&2
  exit 1
fi
jq --arg pkg "$PACKAGE_NAME" --arg path "$PACKAGE_PATH" \
  '.dependencies[$pkg] = $path' "$MANIFEST" >"$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"

# Open the unity project
"$UNITY_PATH" "$PROJECT_PATH"

echo "Init done, remember to configure percisely the package.json before starting your development"
