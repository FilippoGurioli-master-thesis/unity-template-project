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

  find . -type f -print0 |
    xargs -0 grep -Il "$search" |
    xargs sed -i "s/${search//\//\\/}/${replace//\//\\/}/g"
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
