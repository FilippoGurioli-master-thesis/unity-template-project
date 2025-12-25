#!/bin/bash

# helper functions

COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

info() {
  printf "[%bINFO%b] %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$1"
}

warn() {
  printf "[%bWARN%b] %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$1" >&2
}

error() {
  printf "[%bERRO%b] %s\n" "$COLOR_RED" "$COLOR_RESET" "$1" >&2
}

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
    -type f -name "*$search*" -print0 |
    while IFS= read -r -d '' file; do
      local newfile="${file//$search/$replace}"
      mv "$file" "$newfile"
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

toLower() {
  local input="$1"
  if [[ "$input" =~ [A-Z] ]]; then
    warn "Uppercase letters detected. Unity package IDs must be lowercase. Converting to lowercase."
  fi
  printf '%s\n' "$(echo "$input" | tr '[:upper:]' '[:lower:]')"
  return 0
}

#---------------------------------------------------------------------------------------------------

# Read customer values
DOMAIN=$(toLower "$(askWithDefault "Enter the top level domain" "com")")
COMPANY=$(toLower "$(askNonNull "Enter your company name (e.g. 'mycompany')")")
PACKAGE=$(toLower "$(askNonNull "Enter your package name (e.g. 'awesome-tool')")")
NAMESPACE=$(askWithDefault "Enter the default namespace" $(kebabToPascal "$PACKAGE"))
DESCRIPTION=$(askWithDefault "Enter a description" "")
NAME=$(toWords "$NAMESPACE")
GIT_USER=$(git config user.name)
GIT_MAIL=$(git config user.email)

info "The resulting package unique ID is $DOMAIN.$COMPANY.$PACKAGE"
info "The namespace is $NAMESPACE"
info "The package display name is $NAME"

# Replace all directories with matching pattern
info "Renaming dirs with __DOMAIN__=$DOMAIN"
renameDirs "__DOMAIN__" "$DOMAIN"
info "Renaming dirs with __COMPANY__=$COMPANY"
renameDirs "__COMPANY__" "$COMPANY"
info "Renaming dirs with __PACKAGE__=$PACKAGE"
renameDirs "__PACKAGE__" "$PACKAGE"
info "Renaming dirs with __NAMESPACE__=$NAMESPACE"
renameDirs "__NAMESPACE__" "$NAMESPACE"
info "Renaming dirs with __NAME__=$NAME"
renameDirs "__NAME__" "$NAME"

# Rename all files with matching pattern
info "Renaming files with __DOMAIN__=$DOMAIN"
renameFiles "__DOMAIN__" "$DOMAIN"
info "Renaming files with __COMPANY__=$COMPANY"
renameFiles "__COMPANY__" "$COMPANY"
info "Renaming files with __PACKAGE__=$PACKAGE"
renameFiles "__PACKAGE__" "$PACKAGE"
info "Renaming files with __NAMESPACE__=$NAMESPACE"
renameFiles "__NAMESPACE__" "$NAMESPACE"
info "Renaming files with __NAME__=$NAME"
renameFiles "__NAME__" "$NAME"

# Replace words in all files
info "Replacing words with __DOMAIN__=$DOMAIN"
replaceInFiles "__DOMAIN__" "$DOMAIN"
info "Replacing words with __COMPANY__=$COMPANY"
replaceInFiles "__COMPANY__" "$COMPANY"
info "Replacing words with __PACKAGE__=$PACKAGE"
replaceInFiles "__PACKAGE__" "$PACKAGE"
info "Replacing words with __NAMESPACE__=$NAMESPACE"
replaceInFiles "__NAMESPACE__" "$NAMESPACE"
info "Replacing words with __NAME__=$NAME"
replaceInFiles "__NAME__" "$NAME"
info "Replacing words with __DESCRIPTION__=$DESCRIPTION"
replaceInFiles "__DESCRIPTION__" "$DESCRIPTION"
info "Replacing words with __GIT_USER__=$GIT_USER"
replaceInFiles "__GIT_USER__" "$GIT_USER"
info "Replacing words with __GIT_MAIL__=$GIT_MAIL"
replaceInFiles "__GIT_MAIL__" "$GIT_MAIL"

UNITY_PATH=$(find "$HOME/Unity/Hub/Editor" -maxdepth 1 -type d -name "6000*" | sort -V | head -n1)/Editor/Unity
PROJECT_PATH="./TemplateProject"

# Open the unity project
info "Opening Unity project"
"$UNITY_PATH" -projectPath "$PROJECT_PATH" &

# Install deps
info "Installing dotnet and npm dependencies"
npm i
dotnet tool restore

# Install hooks
info "Installing git hooks"
npx lefthook install

# Remove template marker file. The execution of this script means that the project is being used as a product, not developed
info "Removing .template file"
rm .template

# Auto remotion
info "Removing init files since their not needed anymore"
rm init.sh
rm init.ps1

info "Waiting unity to update lock file"
LOCK="Packages/packages-lock.json"
while [ ! -f "$LOCK" ]; do
  sleep 0.5
done
last_mod=""
while true; do
  current_mod=$(stat -c %Y "$LOCK")
  if [ "$current_mod" = "$last_mod" ]; then
    break
  fi
  last_mod=$current_mod
  sleep 2
done

info "Committing changes"
git add .
git commit -m "chore(init): initialize project from template"

info "Init done, remember to configure percisely the package.json before starting your development. Also set a LICENSE before publishing"
