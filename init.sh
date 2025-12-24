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

toWords() {
  local input="$1"
  local output
  if [ -z "$input" ]; then
    echo ""
    return 1
  fi
  output=$(echo "$input" | sed -E \
    -e 's/([A-Z]+)([A-Z][a-z])/\1 \2/g' \
    -e 's/([a-z0-9])([A-Z])/\1 \2/g')
  echo "$output"
}

replaceInFiles() {
  local search="$1"
  local replace="$2"
  local self
  self="./$(basename "${BASH_SOURCE[0]}")"
  find . \
    -path "./TemplateProject/Library" -prune -o \
    -path "./TemplateProject/Logs" -prune -o \
    -path "./TemplateProject/Temp" -prune -o \
    -path "./TemplateProject/obj" -prune -o \
    -path "./init.*" -prune -o \
    -type d -name .git -prune -o \
    -type f ! -path "$self" -print0 |
    xargs -0 grep -Il "$search" |
    xargs sed -i "s/${search//\//\\/}/${replace//\//\\/}/g"
}

renameDirs() {
  local search="$1"
  local replace="$2"
  find . -depth \
    -path "./TemplateProject/Library" -prune -o \
    -path "./TemplateProject/Logs" -prune -o \
    -path "./TemplateProject/Temp" -prune -o \
    -path "./TemplateProject/obj" -prune -o \
    -type d -name "*$search*" -print0 |
    while IFS= read -r -d '' dir; do
      local newdir="${dir//$search/$replace}"
      mv "$dir" "$newdir"
    done
}

renameFiles() {
  local search="$1"
  local replace="$2"
  find . \
    -path "./TemplateProject/Library" -prune -o \
    -path "./TemplateProject/Logs" -prune -o \
    -path "./TemplateProject/Temp" -prune -o \
    -path "./TemplateProject/obj" -prune -o \
    -type f -print0 | while IFS= read -r -d '' file; do
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
NAMESPACE=$(askWithDefault "Enter the default namespace" $(kebabToPascal "$PACKAGE"))
NAME=$(toWords "$NAMESPACE")

echo "The resulting package unique ID is $DOMAIN.$COMPANY.$PACKAGE"
echo "The namespace is $NAMESPACE"
echo "The package display name is $NAME"

# Replace all directories with matching pattern
renameDirs "__DOMAIN__" "$DOMAIN"
renameDirs "__COMPANY__" "$COMPANY"
renameDirs "__PACKAGE__" "$PACKAGE"
renameDirs "__NAMESPACE__" "$NAMESPACE"
renameDirs "__NAME__" "$NAME"

# Rename all files with matching pattern
renameFiles "__DOMAIN__" "$DOMAIN"
renameFiles "__COMPANY__" "$COMPANY"
renameFiles "__PACKAGE__" "$PACKAGE"
renameFiles "__NAMESPACE__" "$NAMESPACE"
renameFiles "__NAME__" "$NAME"

# Replace words in all files
replaceInFiles "__DOMAIN__" "$DOMAIN"
replaceInFiles "__COMPANY__" "$COMPANY"
replaceInFiles "__PACKAGE__" "$PACKAGE"
replaceInFiles "__NAMESPACE__" "$NAMESPACE"
replaceInFiles "__NAME__" "$NAME"

UNITY_PATH=$(find "$HOME/Unity/Hub/Editor" -maxdepth 1 -type d -name "6000*" | sort -V | head -n1)/Editor/Unity
PROJECT_PATH="./TemplateProject"

# Open the unity project
"$UNITY_PATH" -projectPath "$PROJECT_PATH"

# Install hooks
npm i
npx lefthook install

echo "Init done, remember to configure percisely the package.json before starting your development"
